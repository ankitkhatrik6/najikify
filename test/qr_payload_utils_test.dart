import 'package:flutter_test/flutter_test.dart';
import 'package:najikify/core/utils/qr_payload_utils.dart';
import 'package:najikify/models/device.dart';
import 'package:najikify/models/pairing_session.dart';

void main() {
  group('QrPayloadUtils', () {
    final session = PairingSession(
      sessionId: 'session-123',
      deviceId: 'device-abc',
      deviceName: 'Ankit Desktop',
      platform: DevicePlatform.linux,
      ipAddress: '192.168.1.20',
      port: 53317,
      fingerprint: 'FEEDFACE',
      secretToken: 'secret-token',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    test('accepts a plain pairing URI', () {
      final uri = session.toQrUri();
      expect(QrPayloadUtils.extractPairingUri(uri), uri);
      expect(QrPayloadUtils.isValidPairingUri(uri), isTrue);
    });

    test('normalises whitespace, newlines and wrapping quotes', () {
      final uri = session.toQrUri();
      expect(QrPayloadUtils.extractPairingUri('  $uri\n'), uri);
      expect(QrPayloadUtils.extractPairingUri('"$uri"'), uri);
      expect(QrPayloadUtils.extractPairingUri("'$uri'"), uri);
      expect(QrPayloadUtils.extractPairingUri('`$uri`'), uri);
    });

    test('extracts the pairing URI out of surrounding text', () {
      final uri = session.toQrUri();
      expect(
        QrPayloadUtils.extractPairingUri('Pair me now: $uri thanks'),
        uri,
      );
      expect(
        QrPayloadUtils.extractPairingUri('Copied from Najikify:\n$uri\n'),
        uri,
      );
      expect(
        QrPayloadUtils.extractPairingUri('Link ($uri).'),
        uri,
      );
    });

    test('accepts the legacy deep link prefix', () {
      final legacy = 'najikify:pair/${session.toQrUri().split('/').last}';
      expect(QrPayloadUtils.extractPairingUri(legacy), legacy);
      expect(PairingSession.fromQrUri(legacy), isNotNull);
    });

    test('rejects unrelated QR contents', () {
      expect(QrPayloadUtils.extractPairingUri(null), isNull);
      expect(QrPayloadUtils.extractPairingUri(''), isNull);
      expect(QrPayloadUtils.extractPairingUri('   '), isNull);
      expect(QrPayloadUtils.extractPairingUri('https://example.com'), isNull);
      expect(QrPayloadUtils.extractPairingUri('WIFI:S:MyNet;T:WPA;P:pass;;'), isNull);
      expect(QrPayloadUtils.isValidPairingUri('najikify://files/123'), isFalse);
    });

    test('flags non-pairing Najikify links distinctly', () {
      expect(QrPayloadUtils.looksLikeNajikifyLink('najikify://files/123'), isTrue);
      expect(QrPayloadUtils.extractPairingUri('najikify://files/123'), isNull);
      expect(QrPayloadUtils.looksLikeNajikifyLink('https://example.com'), isFalse);
    });

    test('round-trips a session through the extracted payload', () {
      final uri = session.toQrUri();
      final extracted = QrPayloadUtils.extractPairingUri('scanned: $uri');
      expect(extracted, isNotNull);

      final parsed = PairingSession.fromQrUri(extracted!);
      expect(parsed, isNotNull);
      expect(parsed!.deviceId, session.deviceId);
      expect(parsed.deviceName, session.deviceName);
      expect(parsed.ipAddress, session.ipAddress);
      expect(parsed.port, session.port);
      expect(parsed.secretToken, session.secretToken);
    });
  });
}
