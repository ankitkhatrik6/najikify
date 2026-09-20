import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/constants/network_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/crypto_utils.dart';
import '../models/device.dart';
import '../models/pairing_session.dart';
import 'database_service.dart';
import 'discovery_service.dart';
import 'network_service.dart';
import 'settings_service.dart';

class PairingService extends ChangeNotifier {
  static final PairingService _instance = PairingService._internal();
  factory PairingService() => _instance;
  PairingService._internal();

  final SettingsService _settingsService = SettingsService();
  final NetworkService _networkService = NetworkService();
  final DatabaseService _db = DatabaseService();
  final DiscoveryService _discoveryService = DiscoveryService();

  PairingSession? _activeHostSession;

  PairingSession? get activeHostSession => _activeHostSession;

  /// Creates a new temporary pairing session for this host device to display as QR code.
  /// Pass [ipAddress] to force a specific interface (e.g. user-selected Wi-Fi IP).
  PairingSession createHostSession({String? ipAddress}) {
    final primaryIp = (ipAddress != null && ipAddress.isNotEmpty)
        ? ipAddress
        : (_networkService.currentIp ?? '127.0.0.1');
    final session = PairingSession(
      sessionId: CryptoUtils.generateRandomToken(16),
      deviceId: _settingsService.deviceId,
      deviceName: _settingsService.settings.deviceName,
      platform: _settingsService.currentPlatform,
      ipAddress: primaryIp,
      port: _settingsService.settings.serverPort,
      fingerprint: _settingsService.fingerprint,
      secretToken: CryptoUtils.generateRandomToken(24),
      expiresAt: DateTime.now().add(AppConstants.pairingSessionExpiry),
    );

    _activeHostSession = session;
    notifyListeners();
    return session;
  }

  /// Processes scanned QR code URI and initiates mutual handshake with peer.
  Future<Device> processScannedQr(String qrUri, {bool trustDevice = false}) async {
    final session = PairingSession.fromQrUri(qrUri);
    if (session == null) {
      throw const PairingException('Invalid or expired pairing QR code.');
    }

    if (session.deviceId == _settingsService.deviceId) {
      throw const PairingException('Cannot pair with yourself.');
    }

    // Attempt HTTP handshake with remote peer using the temporary pairing credentials
    final targetUrl = Uri.parse('http://${session.ipAddress}:${session.port}${NetworkConstants.endpointPairingRequest}');

    final handshakePayload = {
      'sessionId': session.sessionId,
      'secretToken': session.secretToken,
      'deviceId': _settingsService.deviceId,
      'deviceName': _settingsService.settings.deviceName,
      'platform': _settingsService.currentPlatform.name,
      'ip': _networkService.currentIp ?? '',
      'port': _settingsService.settings.serverPort,
      'fingerprint': _settingsService.fingerprint,
    };

    try {
      final response = await http
          .post(
            targetUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(handshakePayload),
          )
          .timeout(AppConstants.connectionTimeout);

      if (response.statusCode != 200) {
        throw PairingException('Peer rejected pairing (${response.statusCode}): ${response.body}');
      }

      final resData = jsonDecode(response.body) as Map<String, dynamic>;
      if (resData['accepted'] != true) {
        throw PairingException(resData['message'] as String? ?? 'Pairing was declined by peer.');
      }

      final peerDevice = session.toDevice(isTrusted: trustDevice);
      await _db.saveOrUpdateDevice(peerDevice);
      _discoveryService.registerManualDevice(peerDevice);

      return peerDevice;
    } catch (e) {
      if (e is PairingException) rethrow;
      throw PairingException('Failed to reach ${session.deviceName} at ${session.ipAddress}:${session.port}. Check local network.');
    }
  }

  /// Validates an incoming pairing request sent to this device's HTTP server.
  bool validateIncomingPairing(Map<String, dynamic> reqData) {
    if (_activeHostSession == null) return false;
    if (_activeHostSession!.isExpired) return false;

    final reqSessionId = reqData['sessionId'] as String?;
    final reqSecret = reqData['secretToken'] as String?;

    return reqSessionId == _activeHostSession!.sessionId &&
        reqSecret == _activeHostSession!.secretToken;
  }
}
