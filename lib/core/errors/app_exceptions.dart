/// Base exception class for LocalDrop application.
/// Can also be used directly for generic LocalDrop errors.
class LocalDropException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const LocalDropException(this.message, {this.code, this.details});

  @override
  String toString() => 'LocalDropException: $message ${code != null ? '($code)' : ''}';
}

class NetworkUnavailableException extends LocalDropException {
  const NetworkUnavailableException([String message = 'No local network connection available. Connect to Wi-Fi or LAN.'])
      : super(message, code: 'NETWORK_UNAVAILABLE');
}

class DeviceUnavailableException extends LocalDropException {
  final String deviceName;
  const DeviceUnavailableException(this.deviceName, [String message = 'The device is no longer reachable on the local network.'])
      : super(message, code: 'DEVICE_UNAVAILABLE');
}

class ConnectionLostException extends LocalDropException {
  const ConnectionLostException([String message = 'The connection to the remote device was lost during transfer.'])
      : super(message, code: 'CONNECTION_LOST');
}

class TransferRejectedException extends LocalDropException {
  final String reason;
  const TransferRejectedException([this.reason = 'The recipient declined the transfer request.'])
      : super(reason, code: 'TRANSFER_REJECTED');
}

class InsufficientStorageException extends LocalDropException {
  final int requiredBytes;
  final int availableBytes;
  const InsufficientStorageException(this.requiredBytes, this.availableBytes,
      [String message = 'There is not enough storage space to complete this transfer.'])
      : super(message, code: 'INSUFFICIENT_STORAGE');
}

class FilePermissionException extends LocalDropException {
  final String path;
  const FilePermissionException(this.path, [String message = 'Storage access permission denied.'])
      : super(message, code: 'FILE_PERMISSION_DENIED');
}

class SecurityValidationException extends LocalDropException {
  const SecurityValidationException([String message = 'Session validation or checksum verification failed.'])
      : super(message, code: 'SECURITY_VALIDATION_FAILED');
}

class PairingException extends LocalDropException {
  const PairingException(String message) : super(message, code: 'PAIRING_FAILED');
}
