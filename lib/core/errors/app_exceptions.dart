import '../utils/network_utils.dart';

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

/// The peer answered with an identity that was not the one we paired with
/// (a stale IP address, e.g. after switching networks, now belongs to another
/// device — normally another Najikify install). Transfers must not start.
class PeerIdentityMismatchException extends NajikifyException {
  final String deviceName;
  const PeerIdentityMismatchException(
    this.deviceName, [
    String message =
        'The device answering at that address is not the device you paired with. '
        'Its IP address was probably reused by another device — reconnect with a '
        'fresh QR code.',
  ]) : super(message, code: 'PEER_IDENTITY_MISMATCH');
}

/// The two devices cannot talk to each other because they are not on the same
/// local network (different Wi-Fi networks, different routers, or one device is
/// on mobile data). Carries the subnets so the UI can show them concretely.
class DifferentNetworkException extends NajikifyException {
  final String? deviceName;
  final String? peerNetwork;
  final String? localNetwork;

  const DifferentNetworkException(
    super.message, {
    this.deviceName,
    this.peerNetwork,
    this.localNetwork,
    super.details,
  }) : super(code: 'DIFFERENT_NETWORK');
}

/// Maps a [PeerNetworkReport] to the exception that should be thrown, or null
/// when the peer is fine to talk to.
///
/// Keeping the mapping here (instead of at every call site) means the QR
/// scanner, the device list and the send engine all describe a cross-network
/// peer in exactly the same way.
NajikifyException? networkFailureFor(PeerNetworkReport report) {
  switch (report.verdict) {
    case PeerNetworkVerdict.reachable:
    case PeerNetworkVerdict.unreachable:
      // Unreachable is not fatal up front: the peer may just need a moment
      // (screen wake, app start). The transfer itself reports that case.
      return null;
    case PeerNetworkVerdict.noLocalNetwork:
      return NetworkUnavailableException(report.message);
    case PeerNetworkVerdict.differentNetwork:
      return DifferentNetworkException(
        report.message,
        deviceName: report.peerName,
        peerNetwork: report.peerNetworkLabel,
        localNetwork: report.localNetworkLabel,
        details: report,
      );
  }
}
