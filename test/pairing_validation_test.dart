import 'package:flutter_test/flutter_test.dart';
import 'package:localdrop/models/device.dart';
import 'package:localdrop/models/pairing_session.dart';

void main() {
  group('Pairing & QR Validation Tests', () {
    test('PairingSession generates valid URI and parses correctly', () {
      final session = PairingSession(
        sessionId: 'session-1',
        deviceId: 'dev_host',
        deviceName: 'Linux Desktop',
        platform: DevicePlatform.linux,
        ipAddress: '192.168.1.50',
        port: 53317,
        fingerprint: 'SHA256HASH',
        secretToken: 'secret_token_123',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      final uri = session.toQrUri();
      expect(uri.startsWith('localdrop://pair/'), true);

      final parsed = PairingSession.fromQrUri(uri);
      expect(parsed, isNotNull);
      expect(parsed!.secretToken, 'secret_token_123');
      expect(parsed.sessionId, 'session-1');
      expect(parsed.deviceId, 'dev_host');
      expect(parsed.deviceName, 'Linux Desktop');
      expect(parsed.platform, DevicePlatform.linux);
      expect(parsed.ipAddress, '192.168.1.50');
      expect(parsed.port, 53317);
      expect(parsed.fingerprint, 'SHA256HASH');
      expect(parsed.isExpired, false);
    });

    test('Malformed pairing URIs are rejected', () {
      expect(PairingSession.fromQrUri('https://example.com/pair'), isNull);
      expect(PairingSession.fromQrUri('localdrop://pair/!!!not-base64!!!'), isNull);
      expect(PairingSession.fromQrUri('localdrop://pair/'), isNull);
    });

    test('Expired pairing session rejects validation', () {
      final expiredSession = PairingSession(
        sessionId: 'session-2',
        deviceId: 'dev_old',
        deviceName: 'Old Phone',
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.51',
        port: 53317,
        fingerprint: 'HASH',
        secretToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(expiredSession.isExpired, true);
      // Expired URIs must not parse back into a session.
      expect(PairingSession.fromQrUri(expiredSession.toQrUri()), isNull);
    });
  });
}

