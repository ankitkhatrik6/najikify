import 'device.dart';
import 'transfer_file.dart';

enum TransferState {
  queued,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled;

  static TransferState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'queued':
        return TransferState.queued;
      case 'connecting':
        return TransferState.connecting;
      case 'transferring':
        return TransferState.transferring;
      case 'paused':
        return TransferState.paused;
      case 'completed':
        return TransferState.completed;
      case 'failed':
        return TransferState.failed;
      case 'cancelled':
        return TransferState.cancelled;
      default:
        return TransferState.queued;
    }
  }

  bool get isActive => this == TransferState.connecting || this == TransferState.transferring || this == TransferState.queued;
  bool get isDone => this == TransferState.completed || this == TransferState.failed || this == TransferState.cancelled;
}

enum TransferDirection {
  send,
  receive;

  static TransferDirection fromString(String value) {
    return value.toLowerCase() == 'receive' ? TransferDirection.receive : TransferDirection.send;
  }
}

class Transfer {
  final String id;
  final Device peerDevice;
  final TransferDirection direction;
  final TransferState state;
  final List<TransferFile> files;
  final int totalBytes;
  final int transferredBytes;
  final double speed; // Bytes per second
  final int etaSeconds;
  final int currentFileIndex;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String? sessionToken;

  const Transfer({
    required this.id,
    required this.peerDevice,
    required this.direction,
    required this.state,
    required this.files,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.speed = 0.0,
    this.etaSeconds = 0,
    this.currentFileIndex = 0,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.sessionToken,
  });

  double get progress => totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progress * 100).round();
  int get totalFiles => files.length;
  TransferFile? get currentFile => currentFileIndex < files.length ? files[currentFileIndex] : null;

  Transfer copyWith({
    String? id,
    Device? peerDevice,
    TransferDirection? direction,
    TransferState? state,
    List<TransferFile>? files,
    int? totalBytes,
    int? transferredBytes,
    double? speed,
    int? etaSeconds,
    int? currentFileIndex,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    String? sessionToken,
  }) {
    return Transfer(
      id: id ?? this.id,
      peerDevice: peerDevice ?? this.peerDevice,
      direction: direction ?? this.direction,
      state: state ?? this.state,
      files: files ?? this.files,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      speed: speed ?? this.speed,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peer_device_id': peerDevice.id,
      'peer_device_name': peerDevice.name,
      'peer_platform': peerDevice.platform.name,
      'peer_ip': peerDevice.ipAddress,
      'peer_port': peerDevice.port,
      'direction': direction.name,
      'state': state.name,
      'total_bytes': totalBytes,
      'transferred_bytes': transferredBytes,
      'file_count': files.length,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'error_message': errorMessage,
    };
  }
}
