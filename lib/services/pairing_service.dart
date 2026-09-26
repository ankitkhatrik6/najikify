import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/constants/network_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/crypto_utils.dart';
import '../core/utils/network_utils.dart';
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
  ///
  /// Before the handshake the peer address is checked against this device's own
  /// networks: two devices on different Wi-Fi networks (or with one of them on
  /// mobile data) can never complete the request, so the user is told exactly
  /// that instead of waiting for a timeout and reading a vague error.
  Future<Device> processScannedQr(String qrUri, {bool trustDevice = false}) async {
    final session = PairingSession.fromQrUri(qrUri);
    if (session == null) {
      throw const PairingException(
          'Invalid or expired pairing QR code. Ask the other device to show a fresh code.');
    }

    if (session.deviceId == _settingsService.deviceId) {
      throw const PairingException('Cannot pair with yourself.');
    }

    // Fail fast (and precisely) when the two devices cannot see each other.
    final report = await NetworkUtils.checkPeer(
      peerIp: session.ipAddress,
      peerPort: session.port,
      deviceName: session.deviceName,
    );
    final networkFailure = networkFailureFor(report);
    if (networkFailure != null) throw networkFailure;

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

      // The address we dialled must really belong to the device the QR code
      // came from. On a different network that address can be a stranger's
      // device (usually another Najikify install).
      final responderId = resData['deviceId'] as String?;
      if (responderId != null &&
          responderId.isNotEmpty &&
          responderId != session.deviceId) {
        throw PeerIdentityMismatchException(session.deviceName);
      }

      final peerDevice = session.toDevice(isTrusted: trustDevice);
      await _db.saveOrUpdateDevice(peerDevice);
      _discoveryService.registerManualDevice(peerDevice);

      return peerDevice;
    } catch (e) {
      // Our own exceptions already carry an actionable message.
      if (e is NajikifyException) rethrow;
      if (!report.isReachable) {
        throw PairingException(report.message);
      }
      throw PairingException(
          'Failed to reach ${session.deviceName} at ${session.ipAddress}:${session.port}. Check that Najikify is open there and both devices are on the same Wi-Fi network.');
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
