import 'package:flutter_test/flutter_test.dart';
import 'package:localdrop/core/utils/format_utils.dart';
import 'package:localdrop/models/device.dart';
import 'package:localdrop/models/transfer.dart';
import 'package:localdrop/models/transfer_file.dart';

void main() {
  group('Transfer State & Progress Calculation Tests', () {
    late Device testPeer;
    late List<TransferFile> testFiles;

    setUp(() {
      testPeer = Device(
        id: 'peer-1',
        name: "Ankit's Phone",
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.100',
        port: 53317,
        fingerprint: 'FEEDFACE',
        lastSeen: DateTime.now(),
      );

      testFiles = [
        const TransferFile(
          id: 'file-1',
          transferId: 'tx-1',
          name: 'presentation.pdf',
          relativePath: 'presentation.pdf',
          size: 50 * 1024 * 1024, // 50 MB
        ),
        const TransferFile(
          id: 'file-2',
          transferId: 'tx-1',
          name: 'dataset.csv',
          relativePath: 'data/dataset.csv',
          size: 50 * 1024 * 1024, // 50 MB
        ),
      ];
    });

    test('Transfer computes correct progress percentage', () {
      final transfer = Transfer(
        id: 'tx-1',
        peerDevice: testPeer,
        direction: TransferDirection.send,
        state: TransferState.transferring,
        files: testFiles,
        totalBytes: 100 * 1024 * 1024, // 100 MB
        transferredBytes: 50 * 1024 * 1024, // 50 MB
        createdAt: DateTime.now(),
      );

      expect(transfer.progress, 0.5);
      expect(transfer.progressPercent, 50);
      expect(transfer.state.isActive, true);
    });

    test('FormatUtils formats bytes and speed accurately', () {
      expect(FormatUtils.formatBytes(0), '0 B');
      expect(FormatUtils.formatBytes(1024), '1.0 KB');
      expect(FormatUtils.formatBytes(1048576), '1.0 MB');
      expect(FormatUtils.formatBytes(1073741824), '1.0 GB');

      expect(FormatUtils.formatSpeed(15 * 1024 * 1024), '15.0 MB/s');
      expect(FormatUtils.formatEta(65), 'About 1 min 5 sec remaining');
      expect(FormatUtils.formatEta(1), 'About 1 second remaining');
    });

    test('Transfer state transition flags are consistent', () {
      expect(TransferState.queued.isActive, true);
      expect(TransferState.connecting.isActive, true);
      expect(TransferState.transferring.isActive, true);
      expect(TransferState.completed.isActive, false);
      expect(TransferState.failed.isActive, false);
      expect(TransferState.cancelled.isActive, false);
    });
  });
}
