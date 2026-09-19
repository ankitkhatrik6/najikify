/// Network and protocol constants for LocalDrop
class NetworkConstants {
  // Discovery service configuration
  static const String mdnsServiceType = '_localdrop._tcp';
  static const String mdnsDomain = 'local';
  static const int defaultHttpPort = 53317;
  static const int defaultDiscoveryPort = 53318;
  static const String multicastAddressIpv4 = '224.0.0.167';

  // API Endpoints
  static const String apiPrefix = '/api/v1';
  static const String endpointPing = '/api/v1/ping';
  static const String endpointHandshake = '/api/v1/handshake';
  static const String endpointPairingRequest = '/api/v1/pair/request';
  static const String endpointPairingConfirm = '/api/v1/pair/confirm';
  static const String endpointTransferRequest = '/api/v1/transfer/request';
  static const String endpointTransferUpload = '/api/v1/transfer/upload';
  static const String endpointTransferCancel = '/api/v1/transfer/cancel';
  static const String endpointTransferStatus = '/api/v1/transfer/status';
  static const String endpointEventsWs = '/api/v1/events/ws';

  // Custom HTTP headers
  static const String headerDeviceId = 'X-LocalDrop-Device-Id';
  static const String headerDeviceName = 'X-LocalDrop-Device-Name';
  static const String headerPlatform = 'X-LocalDrop-Platform';
  static const String headerSessionToken = 'X-LocalDrop-Session-Token';
  static const String headerTransferId = 'X-LocalDrop-Transfer-Id';
  static const String headerFileId = 'X-LocalDrop-File-Id';
  static const String headerFileSize = 'X-LocalDrop-File-Size';
  static const String headerFileChecksum = 'X-LocalDrop-File-Checksum';
  static const String headerRelativePath = 'X-LocalDrop-Relative-Path';
}
