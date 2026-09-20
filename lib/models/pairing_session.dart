import 'dart:convert';
import 'device.dart';

class PairingSession {
  final String sessionId;
  final String deviceId;
  final String deviceName;
  final DevicePlatform platform;
  final String ipAddress;
  final int port;
  final String fingerprint;
  final String secretToken;
  final DateTime expiresAt;

  const PairingSession({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.fingerprint,
    required this.secretToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Serializes into the najikify://pair QR URI scheme.
  String toQrUri() {
    final payload = {
      'sid': sessionId,
      'did': deviceId,
      'name': deviceName,
      'plt': platform.name,
      'ip': ipAddress,
      'prt': port,
      'fp': fingerprint,
      'sec': secretToken,
      'exp': expiresAt.millisecondsSinceEpoch,
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    return 'najikify://pair/$encoded';
  }

  /// Deserializes a najikify://pair URI into a validated PairingSession.
  static PairingSession? fromQrUri(String uriString) {
    try {
      final uri = Uri.parse(uriString.trim());
      if (uri.scheme != 'najikify' || !uri.host.contains('pair') && uri.path != '/pair' && !uri.toString().startsWith('najikify://pair/')) {
        return null;
      }

      String encodedData = '';
      if (uri.pathSegments.isNotEmpty) {
        encodedData = uri.pathSegments.last;
      } else if (uri.queryParameters.containsKey('data')) {
        encodedData = uri.queryParameters['data']!;
      }

      if (encodedData.isEmpty) return null;

      final normalized = base64Url.normalize(encodedData);
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final expires = DateTime.fromMillisecondsSinceEpoch(data['exp'] as int);
      if (DateTime.now().isAfter(expires)) {
        return null; // Session expired
      }

      return PairingSession(
        sessionId: data['sid'] as String,
        deviceId: data['did'] as String,
        deviceName: data['name'] as String,
        platform: DevicePlatform.fromString(data['plt'] as String),
        ipAddress: data['ip'] as String,
        port: data['prt'] as int,
        fingerprint: data['fp'] as String,
        secretToken: data['sec'] as String,
        expiresAt: expires,
      );
    } catch (_) {
      return null;
    }
  }

  Device toDevice({bool isTrusted = false}) {
    return Device(
      id: deviceId,
      name: deviceName,
      platform: platform,
      ipAddress: ipAddress,
      port: port,
      fingerprint: fingerprint,
      isTrusted: isTrusted,
      lastSeen: DateTime.now(),
    );
  }
}
