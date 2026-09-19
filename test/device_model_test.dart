import 'package:flutter_test/flutter_test.dart';
import 'package:localdrop/models/device.dart';

void main() {
  group('Device Model Tests', () {
    test('Device serialization and deserialization retains fidelity', () {
      final now = DateTime.now();
      final device = Device(
        id: 'dev-12345',
        name: "Ankit's Laptop",
        platform: DevicePlatform.linux,
        ipAddress: '192.168.1.45',
        port: 53317,
        fingerprint: 'A1B2C3D4E5F6',
        isTrusted: true,
        lastSeen: now,
      );

      final map = device.toMap();
      expect(map['id'], 'dev-12345');
      expect(map['platform'], 'linux');
      expect(map['is_trusted'], 1);

      final reconstructed = Device.fromMap(map);
      expect(reconstructed.id, device.id);
      expect(reconstructed.name, device.name);
      expect(reconstructed.platform, DevicePlatform.linux);
      expect(reconstructed.isTrusted, true);
      expect(reconstructed.httpBaseUrl, 'http://192.168.1.45:53317');
    });

    test('DevicePlatform parser handles unknown inputs gracefully', () {
      expect(DevicePlatform.fromString('linux'), DevicePlatform.linux);
      expect(DevicePlatform.fromString('android'), DevicePlatform.android);
      expect(DevicePlatform.fromString('some_weird_os'), DevicePlatform.unknown);
    });
  });
}
