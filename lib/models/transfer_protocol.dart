import 'transfer_file.dart';

class HandshakeRequest {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String fingerprint;
  final int port;
  final String? sessionToken;

  const HandshakeRequest({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.fingerprint,
    required this.port,
    this.sessionToken,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'fingerprint': fingerprint,
        'port': port,
        if (sessionToken != null) 'sessionToken': sessionToken,
      };

  factory HandshakeRequest.fromJson(Map<String, dynamic> json) => HandshakeRequest(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        platform: json['platform'] as String,
        fingerprint: json['fingerprint'] as String? ?? '',
        port: json['port'] as int? ?? 53317,
        sessionToken: json['sessionToken'] as String?,
      );
}

class HandshakeResponse {
  final bool accepted;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String sessionToken;
  final String? message;

  const HandshakeResponse({
    required this.accepted,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.sessionToken,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'accepted': accepted,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'sessionToken': sessionToken,
        if (message != null) 'message': message,
      };

  factory HandshakeResponse.fromJson(Map<String, dynamic> json) => HandshakeResponse(
        accepted: json['accepted'] as bool,
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        platform: json['platform'] as String,
        sessionToken: json['sessionToken'] as String,
        message: json['message'] as String?,
      );
}

class TransferInitRequest {
  final String transferId;
  final String senderDeviceId;
  final String senderDeviceName;
  final String sessionToken;
  final int totalBytes;
  final List<TransferFile> files;

  const TransferInitRequest({
    required this.transferId,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.sessionToken,
    required this.totalBytes,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'senderDeviceId': senderDeviceId,
        'senderDeviceName': senderDeviceName,
        'sessionToken': sessionToken,
        'totalBytes': totalBytes,
        'files': files.map((f) => f.toJson()).toList(),
      };

  factory TransferInitRequest.fromJson(Map<String, dynamic> json) => TransferInitRequest(
        transferId: json['transferId'] as String,
        senderDeviceId: json['senderDeviceId'] as String,
        senderDeviceName: json['senderDeviceName'] as String,
        sessionToken: json['sessionToken'] as String,
        totalBytes: json['totalBytes'] as int,
        files: (json['files'] as List<dynamic>)
            .map((e) => TransferFile.fromJson(e as Map<String, dynamic>, json['transferId'] as String))
            .toList(),
      );
}

class TransferInitResponse {
  final bool accepted;
  final String transferId;
  final String? reason;
  final String? destinationPath;

  const TransferInitResponse({
    required this.accepted,
    required this.transferId,
    this.reason,
    this.destinationPath,
  });

  Map<String, dynamic> toJson() => {
        'accepted': accepted,
        'transferId': transferId,
        if (reason != null) 'reason': reason,
        if (destinationPath != null) 'destinationPath': destinationPath,
      };

  factory TransferInitResponse.fromJson(Map<String, dynamic> json) => TransferInitResponse(
        accepted: json['accepted'] as bool,
        transferId: json['transferId'] as String,
        reason: json['reason'] as String?,
        destinationPath: json['destinationPath'] as String?,
      );
}
