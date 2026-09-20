/// Network and protocol constants for Najikify
class NetworkConstants {
  // Discovery service configuration
  static const String mdnsServiceType = '_najikify._tcp';
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
  static const String headerDeviceId = 'X-Najikify-Device-Id';
  static const String headerDeviceName = 'X-Najikify-Device-Name';
  static const String headerPlatform = 'X-Najikify-Platform';
  static const String headerSessionToken = 'X-Najikify-Session-Token';
  static const String headerTransferId = 'X-Najikify-Transfer-Id';
  static const String headerFileId = 'X-Najikify-File-Id';
  static const String headerFileSize = 'X-Najikify-File-Size';
  static const String headerFileChecksum = 'X-Najikify-File-Checksum';
  static const String headerRelativePath = 'X-Najikify-Relative-Path';
}
