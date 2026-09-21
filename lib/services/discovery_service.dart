import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/network_constants.dart';
import '../models/device.dart';
import 'database_service.dart';
import 'network_service.dart';
import 'settings_service.dart';

class DiscoveryService extends ChangeNotifier {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final SettingsService _settingsService = SettingsService();
  final NetworkService _networkService = NetworkService();
  final DatabaseService _db = DatabaseService();

  RawDatagramSocket? _multicastSocket;
  RawDatagramSocket? _broadcastSocket;
  Timer? _announcementTimer;
  Timer? _staleCheckTimer;

  final Map<String, Device> _discoveredDevices = {};
  bool _isDiscovering = false;

  List<Device> get discoveredDevices => _discoveredDevices.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  bool get isDiscovering => _isDiscovering;

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    await _initSockets();

    // Broadcast immediate discovery probe
    sendProbe();

    // Broadcast self-presence announcements periodically (every 4 seconds)
    // so peers keep seeing us even while a transfer is in progress.
    _announcementTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      announceSelf();
    });

    // Also re-probe the LAN shortly after discovery starts so peers that
    // started first answer back even if the very first probe was lost.
    Timer(const Duration(seconds: 2), () {
      if (_isDiscovering) sendProbe();
    });

    // Check for peers that disappeared. The timeout is intentionally generous
    // (30 s, ~7 missed announcements) so a device is never dropped right
    // after a transfer completes or during a brief Wi-Fi hiccup. Peers that
    // actively transfer are refreshed separately (see touchDevice).
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _removeStaleDevices();
    });
  }

  Future<void> _initSockets() async {
    try {
      // 1. Multicast listener on dedicated port
      _multicastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        NetworkConstants.defaultDiscoveryPort,
        reuseAddress: true,
        reusePort: false,
      );

      _multicastSocket?.broadcastEnabled = true;
      _multicastSocket?.multicastLoopback = false;

      // Join local drop multicast group
      try {
        final mcastAddr = InternetAddress(NetworkConstants.multicastAddressIpv4);
        _multicastSocket?.joinMulticast(mcastAddr);
      } catch (_) {
        // Fall back to subnet broadcast if joinMulticast is restricted on platform
      }

      _multicastSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _multicastSocket?.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram.data, datagram.address.address);
          }
        }
      });
    } catch (_) {
      // Socket bind error fallback
    }

    try {
      // 2. Broadcast sender socket on dynamic port
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket?.broadcastEnabled = true;
    } catch (_) {}
  }

  void _handleIncomingPacket(Uint8List rawData, String senderIp) {
    try {
      final jsonStr = utf8.decode(rawData);
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final messageType = data['type'] as String?;
      final deviceId = data['id'] as String?;

      // Ignore our own self-announcements
      if (deviceId == null || deviceId == _settingsService.deviceId) {
        return;
      }

      if (messageType == 'LOCDROP_PROBE') {
        // Someone asked who is nearby -> immediately announce self back
        announceSelf();
        return;
      }

      if (messageType == 'LOCDROP_ANNOUNCE') {
        final peerPort = data['port'] as int? ?? NetworkConstants.defaultHttpPort;
        final peerName = data['name'] as String? ?? 'Najikify Peer';
        final peerPlatform = DevicePlatform.fromString(data['platform'] as String? ?? 'unknown');
        final peerFingerprint = data['fingerprint'] as String? ?? '';

        // If peer provided an IP, check it, else use incoming sender socket IP
        final effectiveIp = (data['ip'] as String?)?.isNotEmpty == true ? data['ip'] as String : senderIp;

        _db.getDeviceById(deviceId).then((existingDbDevice) {
          final isTrusted = existingDbDevice?.isTrusted ?? false;
          final updatedDevice = Device(
            id: deviceId,
            name: peerName,
            platform: peerPlatform,
            ipAddress: effectiveIp,
            port: peerPort,
            fingerprint: peerFingerprint,
            isTrusted: isTrusted,
            lastSeen: DateTime.now(),
          );

          final previous = _discoveredDevices[deviceId];
          final hasChanged = previous == null ||
              previous.ipAddress != updatedDevice.ipAddress ||
              previous.name != updatedDevice.name;

          _discoveredDevices[deviceId] = updatedDevice;

          // Also update or record in database
          _db.saveOrUpdateDevice(updatedDevice);

          if (hasChanged) {
            notifyListeners();
          }
        });
      }
    } catch (_) {
      // Ignore malformed UDP packet
    }
  }

  /// Sends a presence broadcast to the LAN multicast and local subnet broadcast addresses.
  void announceSelf() {
    final currentIp = _networkService.currentIp;
    if (currentIp == null || currentIp.isEmpty) return;

    final payload = {
      'type': 'LOCDROP_ANNOUNCE',
      'id': _settingsService.deviceId,
      'name': _settingsService.settings.deviceName,
      'platform': _settingsService.currentPlatform.name,
      'ip': currentIp,
      'port': _settingsService.settings.serverPort,
      'fingerprint': _settingsService.fingerprint,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _sendBytes(utf8.encode(jsonEncode(payload)));
  }

  /// Broadcasts a probe requesting all peer devices to respond immediately.
  void sendProbe() {
    final payload = {
      'type': 'LOCDROP_PROBE',
      'id': _settingsService.deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _sendBytes(utf8.encode(jsonEncode(payload)));
  }

  void _sendBytes(List<int> bytes) {
    if (_broadcastSocket == null) return;
    try {
      // 1. Send to multicast group
      _broadcastSocket?.send(
        bytes,
        InternetAddress(NetworkConstants.multicastAddressIpv4),
        NetworkConstants.defaultDiscoveryPort,
      );

      // 2. Also send to 255.255.255.255 broadcast
      _broadcastSocket?.send(
        bytes,
        InternetAddress('255.255.255.255'),
        NetworkConstants.defaultDiscoveryPort,
      );
    } catch (_) {}
  }

  void _removeStaleDevices() {
    final now = DateTime.now();
    final staleIds = <String>[];

    _discoveredDevices.forEach((id, device) {
      // A device stays listed for 30 s after its last sighting. While it is
      // involved in an in-flight transfer it never goes stale (see
      // TransferService.touchPeer below, which refreshes lastSeen whenever
      // bytes flow in either direction).
      final isInFlightTransfer = _inFlightPeerIds.contains(id);
      if (!isInFlightTransfer &&
          now.difference(device.lastSeen) > const Duration(seconds: 30)) {
        staleIds.add(id);
      }
    });

    if (staleIds.isNotEmpty) {
      for (final id in staleIds) {
        _discoveredDevices.remove(id);
      }
      notifyListeners();
    }
  }

  /// Manually add or refresh a device (e.g. from QR scan or direct IP ping)
  void registerManualDevice(Device device) {
    _discoveredDevices[device.id] = device;
    _db.saveOrUpdateDevice(device);
    notifyListeners();
  }

  /// Peers with an actively running transfer. While a transfer is in flight
  /// the peer must stay visible in the device list even if its UDP
  /// announcements are temporarily lost, so the stale-device sweeper skips
  /// these ids. Call [touchPeer] on every chunk to keep lastSeen fresh.
  final Set<String> _inFlightPeerIds = {};

  /// Marks a transfer peer as actively communicating so it is never swept as
  /// stale, and refreshes its lastSeen timestamp (without resetting the
  /// stored device entry otherwise).
  void touchPeer(String deviceId) {
    _inFlightPeerIds.add(deviceId);
    final existing = _discoveredDevices[deviceId];
    if (existing != null) {
      _discoveredDevices[deviceId] =
          existing.copyWith(lastSeen: DateTime.now());
    }
  }

  /// Releases a transfer peer from the in-flight set once its transfer
  /// finishes (completed / failed / cancelled) and refreshes lastSeen so the
  /// peer stays listed for a full freshness window afterwards.
  void releasePeer(String deviceId) {
    _inFlightPeerIds.remove(deviceId);
    final existing = _discoveredDevices[deviceId];
    if (existing != null) {
      _discoveredDevices[deviceId] =
          existing.copyWith(lastSeen: DateTime.now());
    } else {
      // Peer was never discovered via UDP (e.g. QR-only pairing): reload the
      // persisted record so the device list is not empty after a transfer.
      _db.getDeviceById(deviceId).then((stored) {
        if (stored != null) {
          _discoveredDevices[deviceId] =
              stored.copyWith(lastSeen: DateTime.now());
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  Future<void> toggleTrust(Device device) async {
    final newTrust = !device.isTrusted;
    await _db.updateDeviceTrust(device.id, newTrust);
    if (_discoveredDevices.containsKey(device.id)) {
      _discoveredDevices[device.id] = device.copyWith(isTrusted: newTrust);
      notifyListeners();
    }
  }

  Future<void> stopDiscovery() async {
    _announcementTimer?.cancel();
    _staleCheckTimer?.cancel();
    _multicastSocket?.close();
    _broadcastSocket?.close();
    _discoveredDevices.clear();
    _isDiscovering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
