/// Base exception class for Najikify application.
/// Can also be used directly for generic Najikify errors.
class NajikifyException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const NajikifyException(this.message, {this.code, this.details});

  @override
  String toString() => 'NajikifyException: $message ${code != null ? '($code)' : ''}';
}

class NetworkUnavailableException extends NajikifyException {
  const NetworkUnavailableException(
      [super.message = 'No local network connection available. Connect to Wi-Fi or LAN.'])
      : super(code: 'NETWORK_UNAVAILABLE');
}

class DeviceUnavailableException extends NajikifyException {
  final String deviceName;
  const DeviceUnavailableException(this.deviceName, [String message = 'The device is no longer reachable on the local network.'])
      : super(message, code: 'DEVICE_UNAVAILABLE');
}

class ConnectionLostException extends NajikifyException {
  const ConnectionLostException(
      [super.message = 'The connection to the remote device was lost during transfer.'])
      : super(code: 'CONNECTION_LOST');
}

class TransferRejectedException extends NajikifyException {
  final String reason;
  const TransferRejectedException([this.reason = 'The recipient declined the transfer request.'])
      : super(reason, code: 'TRANSFER_REJECTED');
}

class InsufficientStorageException extends NajikifyException {
  final int requiredBytes;
  final int availableBytes;
  const InsufficientStorageException(this.requiredBytes, this.availableBytes,
      [String message = 'There is not enough storage space to complete this transfer.'])
      : super(message, code: 'INSUFFICIENT_STORAGE');
}

class FilePermissionException extends NajikifyException {
  final String path;
  const FilePermissionException(this.path, [String message = 'Storage access permission denied.'])
      : super(message, code: 'FILE_PERMISSION_DENIED');
}

class SecurityValidationException extends NajikifyException {
  const SecurityValidationException(
      [super.message = 'Session validation or checksum verification failed.'])
      : super(code: 'SECURITY_VALIDATION_FAILED');
}

class PairingException extends NajikifyException {
  const PairingException(super.message) : super(code: 'PAIRING_FAILED');
}
