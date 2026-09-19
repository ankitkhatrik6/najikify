enum TransferFileStatus {
  pending,
  transferring,
  completed,
  failed,
  skipped;

  static TransferFileStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TransferFileStatus.pending;
      case 'transferring':
        return TransferFileStatus.transferring;
      case 'completed':
        return TransferFileStatus.completed;
      case 'failed':
        return TransferFileStatus.failed;
      case 'skipped':
        return TransferFileStatus.skipped;
      default:
        return TransferFileStatus.pending;
    }
  }
}

class TransferFile {
  final String id;
  final String transferId;
  final String name;
  final String relativePath;
  final int size;
  final int bytesTransferred;
  final TransferFileStatus status;
  final String? checksum;
  final String? localPath;
  final bool isFolder;

  const TransferFile({
    required this.id,
    required this.transferId,
    required this.name,
    required this.relativePath,
    required this.size,
    this.bytesTransferred = 0,
    this.status = TransferFileStatus.pending,
    this.checksum,
    this.localPath,
    this.isFolder = false,
  });

  double get progress => size > 0 ? (bytesTransferred / size).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => status == TransferFileStatus.completed;

  TransferFile copyWith({
    String? id,
    String? transferId,
    String? name,
    String? relativePath,
    int? size,
    int? bytesTransferred,
    TransferFileStatus? status,
    String? checksum,
    String? localPath,
    bool? isFolder,
  }) {
    return TransferFile(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      size: size ?? this.size,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      checksum: checksum ?? this.checksum,
      localPath: localPath ?? this.localPath,
      isFolder: isFolder ?? this.isFolder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transfer_id': transferId,
      'name': name,
      'relative_path': relativePath,
      'size': size,
      'bytes_transferred': bytesTransferred,
      'status': status.name,
      'checksum': checksum,
      'local_path': localPath,
      'is_folder': isFolder ? 1 : 0,
    };
  }

  factory TransferFile.fromMap(Map<String, dynamic> map) {
    return TransferFile(
      id: map['id'] as String,
      transferId: map['transfer_id'] as String,
      name: map['name'] as String,
      relativePath: map['relative_path'] as String,
      size: map['size'] as int,
      bytesTransferred: map['bytes_transferred'] as int? ?? 0,
      status: TransferFileStatus.fromString(map['status'] as String),
      checksum: map['checksum'] as String?,
      localPath: map['local_path'] as String?,
      isFolder: (map['is_folder'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relativePath': relativePath,
      'size': size,
      'checksum': checksum,
      'isFolder': isFolder,
    };
  }

  factory TransferFile.fromJson(Map<String, dynamic> json, String transferId) {
    return TransferFile(
      id: json['id'] as String,
      transferId: transferId,
      name: json['name'] as String,
      relativePath: json['relativePath'] as String? ?? json['name'] as String,
      size: json['size'] as int? ?? 0,
      checksum: json['checksum'] as String?,
      isFolder: json['isFolder'] as bool? ?? false,
    );
  }
}
