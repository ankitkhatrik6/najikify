import 'package:flutter_test/flutter_test.dart';
import 'package:localdrop/core/utils/file_utils.dart';
import 'package:localdrop/models/transfer_file.dart';
import 'package:localdrop/models/transfer_protocol.dart';

void main() {
  group('File Metadata & Protocol Serialization Tests', () {
    test('TransferFile JSON roundtrip', () {
      const file = TransferFile(
        id: 'file-abc',
        transferId: 'tx-xyz',
        name: 'archive.tar.gz',
        relativePath: 'backups/archive.tar.gz',
        size: 104857600,
        bytesTransferred: 52428800,
        status: TransferFileStatus.transferring,
        checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final json = file.toJson();
      final restored = TransferFile.fromJson(json, file.transferId);

      expect(restored.id, file.id);
      expect(restored.relativePath, 'backups/archive.tar.gz');
      expect(restored.size, 104857600);
      expect(restored.checksum, file.checksum);
    });

    test('FileUtils sanitizes directory traversal safely', () {
      expect(FileUtils.sanitizeRelativePath('../../../etc/passwd'), 'etc/passwd');
      expect(FileUtils.sanitizeRelativePath('foo/bar\\baz'), 'foo/bar/baz');
      expect(FileUtils.sanitizeRelativePath('../../docs/manual.pdf'), 'docs/manual.pdf');
    });

    test('Handshake and TransferInit protocol models serialize faithfully', () {
      const hsReq = HandshakeRequest(
        deviceId: 'dev_1',
        deviceName: 'Android Node',
        platform: 'android',
        fingerprint: 'PRINT',
        port: 53317,
      );
      final hsJson = hsReq.toJson();
      final hsRestored = HandshakeRequest.fromJson(hsJson);
      expect(hsRestored.deviceId, 'dev_1');
      expect(hsRestored.platform, 'android');

      const initReq = TransferInitRequest(
        transferId: 't-123',
        senderDeviceId: 'dev_1',
        senderDeviceName: 'Android Node',
        sessionToken: 'token_abc',
        totalBytes: 5000,
        files: [],
      );
      final initJson = initReq.toJson();
      final initRestored = TransferInitRequest.fromJson(initJson);
      expect(initRestored.transferId, 't-123');
      expect(initRestored.sessionToken, 'token_abc');
    });
  });
}
