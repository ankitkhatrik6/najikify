import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/network_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/crypto_utils.dart';
import '../core/utils/file_utils.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../models/transfer_file.dart';
import '../models/transfer_protocol.dart';
import 'database_service.dart';
import 'file_service.dart';
import 'history_service.dart';
import 'pairing_service.dart';
import 'settings_service.dart';

typedef IncomingTransferCallback = Future<bool> Function(
  Device sender,
  List<TransferFile> files,
  int totalBytes,
  String savePath,
);

class TransferService extends ChangeNotifier {
  static final TransferService _instance = TransferService._internal();
  factory TransferService() => _instance;
  TransferService._internal();

  final SettingsService _settingsService = SettingsService();
  final FileService _fileService = FileService();
  final DatabaseService _db = DatabaseService();
  final HistoryService _historyService = HistoryService();
  final PairingService _pairingService = PairingService();

  HttpServer? _server;
  bool _isServerRunning = false;

  final Map<String, Transfer> _transfers = {};
  final Map<String, IOSink> _activeFileSinks = {};

  IncomingTransferCallback? onIncomingTransfer;

  bool get isServerRunning => _isServerRunning;
  List<Transfer> get allTransfers => _transfers.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Transfer> get activeTransfers =>
      _transfers.values.where((t) => t.state.isActive).toList();

  List<Transfer> get completedTransfers =>
      _transfers.values.where((t) => t.state == TransferState.completed).toList();

  List<Transfer> get failedTransfers =>
      _transfers.values.where((t) => t.state == TransferState.failed || t.state == TransferState.cancelled).toList();

  /// Starts the embedded Najikify HTTP daemon on the configured port.
  Future<void> startServer() async {
    if (_isServerRunning) return;

    final port = _settingsService.settings.serverPort;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _isServerRunning = true;
      notifyListeners();

      _server?.listen((HttpRequest request) {
        _handleIncomingRequest(request);
      }, onError: (error) {
        // Server listener error
      });
    } catch (e) {
      _isServerRunning = false;
      notifyListeners();
    }
  }

  Future<void> _handleIncomingRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // Enable CORS for cross-device compatibility
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (path == NetworkConstants.endpointPing) {
        await _handlePing(request);
      } else if (path == NetworkConstants.endpointHandshake && method == 'POST') {
        await _handleHandshake(request);
      } else if (path == NetworkConstants.endpointPairingRequest && method == 'POST') {
        await _handlePairingRequest(request);
      } else if (path == NetworkConstants.endpointTransferRequest && method == 'POST') {
        await _handleTransferInit(request);
      } else if (path == NetworkConstants.endpointTransferUpload && method == 'POST') {
        await _handleFileUpload(request);
      } else if (path == NetworkConstants.endpointTransferCancel && method == 'POST') {
        await _handleCancelTransfer(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Endpoint not found');
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handlePing(HttpRequest request) async {
    final response = {
      'id': _settingsService.deviceId,
      'name': _settingsService.settings.deviceName,
      'platform': _settingsService.currentPlatform.name,
      'fingerprint': _settingsService.fingerprint,
      'port': _settingsService.settings.serverPort,
      'version': AppConstants.appVersion,
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }

  Future<void> _handleHandshake(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    HandshakeRequest.fromJson(data);

    final sessionToken = CryptoUtils.generateRandomToken(32);

    final response = HandshakeResponse(
      accepted: true,
      deviceId: _settingsService.deviceId,
      deviceName: _settingsService.settings.deviceName,
      platform: _settingsService.currentPlatform.name,
      sessionToken: sessionToken,
    );

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response.toJson()));
    await request.response.close();
  }

  Future<void> _handlePairingRequest(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final isValid = _pairingService.validateIncomingPairing(data);
    if (!isValid) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write(jsonEncode({'accepted': false, 'message': 'Invalid or expired pairing session'}));
      await request.response.close();
      return;
    }

    final peerDevice = Device(
      id: data['deviceId'] as String,
      name: data['deviceName'] as String,
      platform: DevicePlatform.fromString(data['platform'] as String),
      ipAddress: data['ip'] as String? ?? request.connectionInfo?.remoteAddress.address ?? '',
      port: data['port'] as int? ?? NetworkConstants.defaultHttpPort,
      fingerprint: data['fingerprint'] as String? ?? '',
      isTrusted: true,
      lastSeen: DateTime.now(),
    );

    await _db.saveOrUpdateDevice(peerDevice);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'accepted': true, 'message': 'Pairing confirmed'}));
    await request.response.close();
  }

  Future<void> _handleTransferInit(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final transferReq = TransferInitRequest.fromJson(data);

    // Retrieve sender device from database if known
    final existingDevice = await _db.getDeviceById(transferReq.senderDeviceId);
    final isTrusted = existingDevice?.isTrusted ?? false;

    final peerDevice = Device(
      id: transferReq.senderDeviceId,
      name: transferReq.senderDeviceName,
      platform: DevicePlatform.fromString(request.headers.value(NetworkConstants.headerPlatform) ?? 'unknown'),
      ipAddress: request.connectionInfo?.remoteAddress.address ?? '',
      port: NetworkConstants.defaultHttpPort,
      fingerprint: '',
      isTrusted: isTrusted,
      lastSeen: DateTime.now(),
    );

    // Check if auto-accept trusted is on
    bool accepted = false;
    if (isTrusted && _settingsService.settings.autoAcceptTrusted && !_settingsService.settings.askBeforeReceiving) {
      accepted = true;
    } else if (onIncomingTransfer != null) {
      accepted = await onIncomingTransfer!(
        peerDevice,
        transferReq.files,
        transferReq.totalBytes,
        _settingsService.settings.downloadPath,
      );
    } else {
      accepted = true; // Default accept if callback not hooked
    }

    if (!accepted) {
      final res = TransferInitResponse(
        accepted: false,
        transferId: transferReq.transferId,
        reason: 'Declined by recipient',
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(res.toJson()));
      await request.response.close();
      return;
    }

    // Register active incoming transfer
    final newTransfer = Transfer(
      id: transferReq.transferId,
      peerDevice: peerDevice,
      direction: TransferDirection.receive,
      state: TransferState.transferring,
      files: transferReq.files,
      totalBytes: transferReq.totalBytes,
      transferredBytes: 0,
      createdAt: DateTime.now(),
      sessionToken: transferReq.sessionToken,
    );

    _transfers[newTransfer.id] = newTransfer;
    notifyListeners();

    final res = TransferInitResponse(
      accepted: true,
      transferId: transferReq.transferId,
      destinationPath: _settingsService.settings.downloadPath,
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(res.toJson()));
    await request.response.close();
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
    final transferId = request.headers.value(NetworkConstants.headerTransferId);
    final fileId = request.headers.value(NetworkConstants.headerFileId);
    final relativePath = request.headers.value(NetworkConstants.headerRelativePath);
    final fileSizeStr = request.headers.value(NetworkConstants.headerFileSize);
    final checksum = request.headers.value(NetworkConstants.headerFileChecksum);

    if (transferId == null || fileId == null || relativePath == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing required transfer headers');
      await request.response.close();
      return;
    }

    final transfer = _transfers[transferId];
    if (transfer == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Transfer session expired or not found');
      await request.response.close();
      return;
    }

    final fileSize = int.tryParse(fileSizeStr ?? '0') ?? 0;
    final downloadDir = _settingsService.settings.downloadPath;

    // Prepare destination file with conflict resolution
    final destinationPath = await _fileService.prepareDestinationPath(
      downloadBasePath: downloadDir,
      relativePath: relativePath,
      conflictAction: FileConflictAction.keepBoth,
    );

    final targetFile = File(destinationPath);
    final sink = targetFile.openWrite();
    _activeFileSinks[transferId] = sink;

    int bytesForThisFile = 0;
    int lastSampleBytes = transfer.transferredBytes;
    DateTime lastSampleTime = DateTime.now();

    try {
      await for (final chunk in request) {
        sink.add(chunk);
        bytesForThisFile += chunk.length;

        final newTotalTransferred = transfer.transferredBytes + chunk.length;

        // Calculate speed & ETA via moving time window
        final now = DateTime.now();
        final elapsedMs = now.difference(lastSampleTime).inMilliseconds;
        double speed = transfer.speed;
        int eta = transfer.etaSeconds;

        if (elapsedMs >= 500) {
          final deltaBytes = newTotalTransferred - lastSampleBytes;
          speed = (deltaBytes / (elapsedMs / 1000.0)).clamp(0.0, 500 * 1024 * 1024);
          lastSampleBytes = newTotalTransferred;
          lastSampleTime = now;

          if (speed > 0) {
            final remainingBytes = transfer.totalBytes - newTotalTransferred;
            eta = (remainingBytes / speed).round();
          }
        }

        // Update file progress
        final updatedFiles = transfer.files.map((f) {
          if (f.id == fileId) {
            return f.copyWith(
              bytesTransferred: bytesForThisFile,
              status: bytesForThisFile >= fileSize ? TransferFileStatus.completed : TransferFileStatus.transferring,
              localPath: destinationPath,
            );
          }
          return f;
        }).toList();

        _transfers[transferId] = transfer.copyWith(
          transferredBytes: newTotalTransferred,
          speed: speed,
          etaSeconds: eta,
          files: updatedFiles,
        );

        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      _activeFileSinks.remove(transferId);

      // Verify file checksum if provided
      if (checksum != null && checksum.isNotEmpty) {
        final computedChecksum = await CryptoUtils.computeFileChecksum(targetFile);
        if (computedChecksum != checksum) {
          throw SecurityValidationException('Checksum mismatch for file $relativePath');
        }
      }

      // Check if all files in transfer are completed
      final updatedTransfer = _transfers[transferId]!;
      final allDone = updatedTransfer.files.every((f) => f.isCompleted);

      if (allDone) {
        final completed = updatedTransfer.copyWith(
          state: TransferState.completed,
          completedAt: DateTime.now(),
          speed: 0,
          etaSeconds: 0,
        );
        _transfers[transferId] = completed;
        await _historyService.addTransfer(completed);
        notifyListeners();
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode({'success': true, 'fileId': fileId, 'path': destinationPath}));
      await request.response.close();
    } catch (e) {
      await sink.close();
      _activeFileSinks.remove(transferId);

      _transfers[transferId] = transfer.copyWith(
        state: TransferState.failed,
        errorMessage: e.toString(),
      );
      notifyListeners();

      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  Future<void> _handleCancelTransfer(HttpRequest request) async {
    final transferId = request.headers.value(NetworkConstants.headerTransferId);
    if (transferId != null && _transfers.containsKey(transferId)) {
      await cancelTransfer(transferId);
    }
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
  }

  // ==========================================
  // CLIENT SENDER ENGINE
  // ==========================================

  /// Initiates a real streaming transfer of one or more files to a remote peer device.
  Future<String> sendFiles({
    required Device peerDevice,
    required List<FileEntityEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw const NajikifyException('No files selected to send.');
    }

    final transferId = const Uuid().v4();
    int totalBytes = 0;

    final transferFiles = <TransferFile>[];
    for (final entry in entries) {
      final fileId = const Uuid().v4();
      final size = entry.size;
      totalBytes += size;

      transferFiles.add(TransferFile(
        id: fileId,
        transferId: transferId,
        name: p.basename(entry.file.path),
        relativePath: entry.relativePath,
        size: size,
        localPath: entry.file.path,
        isFolder: entry.isFolder,
        status: TransferFileStatus.pending,
      ));
    }

    final transfer = Transfer(
      id: transferId,
      peerDevice: peerDevice,
      direction: TransferDirection.send,
      state: TransferState.connecting,
      files: transferFiles,
      totalBytes: totalBytes,
      transferredBytes: 0,
      createdAt: DateTime.now(),
    );

    _transfers[transferId] = transfer;
    notifyListeners();

    _runSendWorker(transfer, entries);
    return transferId;
  }

  Future<void> _runSendWorker(Transfer initialTransfer, List<FileEntityEntry> entries) async {
    final transferId = initialTransfer.id;
    final peer = initialTransfer.peerDevice;

    try {
      // 1. Handshake with remote peer
      final handshakeUri = Uri.parse('${peer.httpBaseUrl}${NetworkConstants.endpointHandshake}');
      final handshakeReq = HandshakeRequest(
        deviceId: _settingsService.deviceId,
        deviceName: _settingsService.settings.deviceName,
        platform: _settingsService.currentPlatform.name,
        fingerprint: _settingsService.fingerprint,
        port: _settingsService.settings.serverPort,
      );

      final hsRes = await http.post(
        handshakeUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(handshakeReq.toJson()),
      ).timeout(AppConstants.connectionTimeout);

      if (hsRes.statusCode != 200) {
        throw DeviceUnavailableException(peer.name, 'Handshake rejected by peer: ${hsRes.body}');
      }

      final hsData = HandshakeResponse.fromJson(jsonDecode(hsRes.body) as Map<String, dynamic>);
      final sessionToken = hsData.sessionToken;

      // 2. Transfer init request
      final initUri = Uri.parse('${peer.httpBaseUrl}${NetworkConstants.endpointTransferRequest}');
      final initReq = TransferInitRequest(
        transferId: transferId,
        senderDeviceId: _settingsService.deviceId,
        senderDeviceName: _settingsService.settings.deviceName,
        sessionToken: sessionToken,
        totalBytes: initialTransfer.totalBytes,
        files: initialTransfer.files,
      );

      final initRes = await http.post(
        initUri,
        headers: {
          'Content-Type': 'application/json',
          NetworkConstants.headerPlatform: _settingsService.currentPlatform.name,
        },
        body: jsonEncode(initReq.toJson()),
      ).timeout(AppConstants.transferTimeout);

      if (initRes.statusCode != 200) {
        throw const TransferRejectedException('Recipient declined or failed to accept transfer');
      }

      final initData = TransferInitResponse.fromJson(jsonDecode(initRes.body) as Map<String, dynamic>);
      if (!initData.accepted) {
        throw TransferRejectedException(initData.reason ?? 'Recipient rejected the transfer');
      }

      // 3. Begin streaming each file
      _transfers[transferId] = _transfers[transferId]!.copyWith(
        state: TransferState.transferring,
        sessionToken: sessionToken,
      );
      notifyListeners();

      int transferredSoFar = 0;
      int lastSampleBytes = 0;
      DateTime lastSampleTime = DateTime.now();

      final httpClient = HttpClient();
      httpClient.connectionTimeout = AppConstants.connectionTimeout;

      for (int i = 0; i < entries.length; i++) {
        // Check if user cancelled
        if (_transfers[transferId]?.state == TransferState.cancelled) {
          httpClient.close();
          return;
        }

        final entry = entries[i];
        final tFile = initialTransfer.files[i];

        _transfers[transferId] = _transfers[transferId]!.copyWith(
          currentFileIndex: i,
        );
        notifyListeners();

        // Calculate file checksum
        final checksum = await CryptoUtils.computeFileChecksum(entry.file);

        final uploadUri = Uri.parse('${peer.httpBaseUrl}${NetworkConstants.endpointTransferUpload}');
        final req = await httpClient.postUrl(uploadUri);

        req.headers.set(NetworkConstants.headerTransferId, transferId);
        req.headers.set(NetworkConstants.headerFileId, tFile.id);
        req.headers.set(NetworkConstants.headerRelativePath, entry.relativePath);
        req.headers.set(NetworkConstants.headerFileSize, entry.size.toString());
        req.headers.set(NetworkConstants.headerFileChecksum, checksum);
        req.headers.set(NetworkConstants.headerSessionToken, sessionToken);

        final fileStream = entry.file.openRead();
        int fileBytesSent = 0;

        await for (final chunk in fileStream) {
          if (_transfers[transferId]?.state == TransferState.cancelled) {
            req.abort();
            httpClient.close();
            return;
          }

          req.add(chunk);
          fileBytesSent += chunk.length;
          transferredSoFar += chunk.length;

          // Compute moving speed
          final now = DateTime.now();
          final elapsed = now.difference(lastSampleTime).inMilliseconds;
          double speed = _transfers[transferId]!.speed;
          int eta = _transfers[transferId]!.etaSeconds;

          if (elapsed >= 500) {
            final delta = transferredSoFar - lastSampleBytes;
            speed = (delta / (elapsed / 1000.0)).clamp(0.0, 500 * 1024 * 1024);
            lastSampleBytes = transferredSoFar;
            lastSampleTime = now;

            if (speed > 0) {
              final remaining = initialTransfer.totalBytes - transferredSoFar;
              eta = (remaining / speed).round();
            }
          }

          final updatedFiles = _transfers[transferId]!.files.map((f) {
            if (f.id == tFile.id) {
              return f.copyWith(
                bytesTransferred: fileBytesSent,
                status: fileBytesSent >= entry.size ? TransferFileStatus.completed : TransferFileStatus.transferring,
              );
            }
            return f;
          }).toList();

          _transfers[transferId] = _transfers[transferId]!.copyWith(
            transferredBytes: transferredSoFar,
            speed: speed,
            etaSeconds: eta,
            files: updatedFiles,
          );
          notifyListeners();
        }

        final res = await req.close();
        if (res.statusCode != HttpStatus.ok) {
          throw NajikifyException('Error uploading file ${entry.relativePath}: HTTP ${res.statusCode}');
        }
      }

      httpClient.close();

      // Mark transfer completed
      final completed = _transfers[transferId]!.copyWith(
        state: TransferState.completed,
        completedAt: DateTime.now(),
        speed: 0,
        etaSeconds: 0,
      );
      _transfers[transferId] = completed;
      await _historyService.addTransfer(completed);
      notifyListeners();
    } catch (e) {
      final current = _transfers[transferId];
      if (current != null && current.state != TransferState.cancelled) {
        final failed = current.copyWith(
          state: TransferState.failed,
          errorMessage: e.toString(),
          speed: 0,
          etaSeconds: 0,
        );
        _transfers[transferId] = failed;
        await _historyService.addTransfer(failed);
        notifyListeners();
      }
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer == null) return;

    _transfers[transferId] = transfer.copyWith(
      state: TransferState.cancelled,
      speed: 0,
      etaSeconds: 0,
    );

    // Close any active write sink
    if (_activeFileSinks.containsKey(transferId)) {
      try {
        await _activeFileSinks[transferId]?.close();
        _activeFileSinks.remove(transferId);
      } catch (_) {}
    }

    // Attempt to notify remote peer
    try {
      final cancelUri = Uri.parse('${transfer.peerDevice.httpBaseUrl}${NetworkConstants.endpointTransferCancel}');
      await http.post(
        cancelUri,
        headers: {NetworkConstants.headerTransferId: transferId},
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    notifyListeners();
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _isServerRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
