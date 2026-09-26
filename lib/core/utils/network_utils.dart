import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A local IPv4 address together with the prefix length (netmask) the system
/// reports for it, e.g. `192.168.1.5/24`.
///
/// The prefix length is what answers the question Najikify cares about most:
/// *"is this peer really on my local network?"* — a device on `192.168.4.x` can
/// never answer a request from `192.168.1.x`, no matter how long we wait.
@immutable
class LocalSubnet {
  final String address;
  final int prefixLength;
  final String interfaceName;

  const LocalSubnet({
    required this.address,
    this.prefixLength = 24,
    this.interfaceName = '',
  });

  /// `192.168.1.0/24` — the network this address belongs to.
  String get networkLabel =>
      '${NetworkUtils.networkAddress(address, prefixLength)}/$prefixLength';

  /// `192.168.1.x` — how the network is shown to a human.
  String get maskedLabel => NetworkUtils.maskedNetwork(address, prefixLength);

  @override
  String toString() => '$address/$prefixLength ($interfaceName)';
}

/// What a peer's address means for this device.
enum PeerNetworkVerdict {
  /// The peer answered on its Najikify port — it is reachable right now.
  reachable,

  /// The peer's address is outside every local subnet: another Wi-Fi network,
  /// another router, or plain mobile data.
  differentNetwork,

  /// Same subnet, but nothing is listening (app closed, screen locked,
  /// firewall, device asleep).
  unreachable,

  /// This device has no Wi-Fi/LAN address at all, so nothing on a local
  /// network could ever be reached.
  noLocalNetwork,
}

/// Outcome of [NetworkUtils.checkPeer]: a verdict plus a ready-to-show,
/// human friendly explanation naming both devices and networks.
@immutable
class PeerNetworkReport {
  final PeerNetworkVerdict verdict;
  final String peerAddress;
  final int peerPort;
  final String? peerName;
  final List<LocalSubnet> localSubnets;

  const PeerNetworkReport({
    required this.verdict,
    required this.peerAddress,
    required this.peerPort,
    this.peerName,
    this.localSubnets = const [],
  });

  bool get isReachable => verdict == PeerNetworkVerdict.reachable;

  /// True when the address cannot be part of this device's network at all.
  bool get isDifferentNetwork =>
      verdict == PeerNetworkVerdict.differentNetwork ||
      verdict == PeerNetworkVerdict.noLocalNetwork;

  /// `"Pixel 8"` or `The other device` — used in every message below.
  String get peerLabel =>
      (peerName == null || peerName!.isEmpty) ? 'The other device' : '"$peerName"';

  /// `192.168.1.x` of the first local subnet ('' when unknown).
  String get localNetworkLabel =>
      localSubnets.isEmpty ? '' : localSubnets.first.maskedLabel;

  /// `192.168.4.x` of the peer address.
  String get peerNetworkLabel => NetworkUtils.maskedNetwork(
        peerAddress,
        localSubnets.isEmpty ? 24 : localSubnets.first.prefixLength,
      );

  /// User-facing explanation. Empty when the peer is reachable.
  String get message {
    switch (verdict) {
      case PeerNetworkVerdict.reachable:
        return '';
      case PeerNetworkVerdict.noLocalNetwork:
        return 'This device has no Wi-Fi or LAN address. Najikify transfers '
            'files only inside one local network — join the same Wi-Fi router '
            'or hotspot as $peerLabel.';
      case PeerNetworkVerdict.differentNetwork:
        final peerNet =
            peerNetworkLabel.isEmpty ? peerAddress : peerNetworkLabel;
        final localNet = localNetworkLabel.isEmpty
            ? 'the network this device is on'
            : localNetworkLabel;
        return '$peerLabel is on a different network ($peerNet) than this '
            'device ($localNet). Both devices must be on the same Wi-Fi router '
            'or LAN — connect them to the same network, or turn on a hotspot '
            'on one device and join it from the other.';
      case PeerNetworkVerdict.unreachable:
        return 'Cannot reach $peerLabel at $peerAddress:$peerPort. Check that '
            'Najikify is open on that device, its screen is unlocked and both '
            'devices are on the same Wi-Fi network.';
    }
  }

  @override
  String toString() => 'PeerNetworkReport(${verdict.name}, $peerAddress)';
}

class NetworkUtils {
  NetworkUtils._();

  /// Method channel implemented by the Android host (`NetworkInspector.kt`),
  /// which can read the real prefix length of every link address.
  static const MethodChannel _channel = MethodChannel('najikify/network');

  /// Test seam: replaces the platform lookup of local link addresses.
  @visibleForTesting
  static Future<List<LocalSubnet>> Function()? localSubnetsOverride;

  /// Test seam: replaces the TCP reachability probe.
  @visibleForTesting
  static Future<bool> Function(String host, int port, Duration timeout)?
      probeOverride;

  // ---------------------------------------------------------------------------
  // Pure IPv4 maths (no I/O, no plugins — fully unit tested)
  // ---------------------------------------------------------------------------

  /// Parses `a.b.c.d` into an unsigned 32-bit int, or null when invalid.
  static int? parseIpv4(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return null;
    var value = 0;
    for (final part in parts) {
      if (part.isEmpty || part.length > 3) return null;
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      value = (value << 8) | octet;
    }
    return value;
  }

  /// `true` when [ip] is a syntactically valid IPv4 address.
  static bool isValidIpv4(String ip) => parseIpv4(ip) != null;

  /// Bit mask for [prefixLength] (24 -> 255.255.255.0).
  static int prefixMask(int prefixLength) {
    final length = prefixLength.clamp(0, 32);
    if (length == 0) return 0;
    return (0xFFFFFFFF << (32 - length)) & 0xFFFFFFFF;
  }

  /// Network address of [ip] under [prefixLength], e.g. `192.168.1.0`.
  static String networkAddress(String ip, int prefixLength) {
    final value = parseIpv4(ip);
    if (value == null) return ip;
    final network = value & prefixMask(prefixLength);
    return '${(network >> 24) & 0xFF}.${(network >> 16) & 0xFF}.'
        '${(network >> 8) & 0xFF}.${network & 0xFF}';
  }

  /// True when both addresses sit in the same [prefixLength] network.
  static bool sameSubnet(String a, String b, int prefixLength) {
    final left = parseIpv4(a);
    final right = parseIpv4(b);
    if (left == null || right == null) return false;
    final mask = prefixMask(prefixLength);
    return (left & mask) == (right & mask);
  }

  /// `192.168.1.x` / `192.168.x.x` / `10.x.x.x` — a network as users read it.
  static String maskedNetwork(String ip, int prefixLength) {
    final value = parseIpv4(ip);
    if (value == null) return ip;
    final a = (value >> 24) & 0xFF;
    final b = (value >> 16) & 0xFF;
    final c = (value >> 8) & 0xFF;
    if (prefixLength >= 24) return '$a.$b.$c.x';
    if (prefixLength >= 16) return '$a.$b.x.x';
    return '$a.x.x.x';
  }

  /// Best-effort prefix length for platforms that do not report one. Matches
  /// how consumer routers are normally configured.
  static int guessPrefixLength(String ip) {
    final value = parseIpv4(ip);
    if (value == null) return 24;
    final first = (value >> 24) & 0xFF;
    final second = (value >> 16) & 0xFF;
    if (first == 172 && second >= 16 && second <= 31) return 16;
    return 24;
  }

  /// True when [ip] belongs to any of [subnets].
  static bool isInAnySubnet(String ip, List<LocalSubnet> subnets) {
    for (final subnet in subnets) {
      if (sameSubnet(ip, subnet.address, subnet.prefixLength)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Local interface discovery
  // ---------------------------------------------------------------------------

  /// Local IPv4 addresses with the prefix length the OS reports for each.
  ///
  /// Order of preference: the Android host channel (real netmasks) -> `ip -o -4
  /// addr` on Linux -> `NetworkInterface.list()` with a conventional guess.
  static Future<List<LocalSubnet>> localSubnets() async {
    final override = localSubnetsOverride;
    if (override != null) return override();

    final fromPlatform = await _platformSubnets();
    if (fromPlatform.isNotEmpty) return fromPlatform;

    final fromIp = await _subnetsFromIpCommand();
    if (fromIp.isNotEmpty) return fromIp;

    return _subnetsFromInterfaces();
  }

  static Future<List<LocalSubnet>> _platformSubnets() async {
    try {
      final result = await _channel.invokeListMethod<dynamic>('getLinkAddresses');
      if (result == null) return const [];
      final subnets = <LocalSubnet>[];
      for (final entry in result) {
        if (entry is! Map) continue;
        final address = entry['address'];
        if (address is! String || !isValidIpv4(address)) continue;
        final prefix = entry['prefixLength'];
        subnets.add(LocalSubnet(
          address: address,
          prefixLength: prefix is int && prefix >= 0 && prefix <= 32
              ? prefix
              : guessPrefixLength(address),
          interfaceName: entry['interfaceName'] as String? ?? '',
        ));
      }
      return subnets;
    } catch (_) {
      // MissingPluginException on Linux desktop and in tests: fall through to
      // the platform specific discovery below.
      return const [];
    }
  }

  /// Linux: `ip -o -4 addr show` prints `inet 192.168.1.5/24 ...`.
  static Future<List<LocalSubnet>> _subnetsFromIpCommand() async {
    if (!Platform.isLinux && !Platform.isMacOS) return const [];
    try {
      final result = await Process.run('ip', ['-o', '-4', 'addr', 'show']);
      if (result.exitCode != 0) return const [];
      final pattern = RegExp(r'inet (\d+\.\d+\.\d+\.\d+)/(\d+)');
      final subnets = <LocalSubnet>[];
      for (final line in (result.stdout as String).split('\n')) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;
        final address = match.group(1)!;
        if (address.startsWith('127.')) continue;
        final iface = _interfaceNameOf(line);
        if (_isVirtualInterface(iface)) continue;
        subnets.add(LocalSubnet(
          address: address,
          prefixLength: int.tryParse(match.group(2)!) ?? 24,
          interfaceName: iface,
        ));
      }
      return subnets;
    } catch (_) {
      return const [];
    }
  }

  /// `2: wlan0    inet 192.168.1.5/24 ...` -> `wlan0`
  static String _interfaceNameOf(String ipLine) {
    final match = RegExp(r'^\d+:\s+([^:\s]+)').firstMatch(ipLine.trim());
    return match?.group(1) ?? '';
  }

  static Future<List<LocalSubnet>> _subnetsFromInterfaces() async {
    final interfaces = await getLocalIpv4Interfaces();
    return interfaces
        .map((info) => LocalSubnet(
              address: info.address,
              prefixLength: guessPrefixLength(info.address),
              interfaceName: info.name,
            ))
        .toList();
  }

  static bool _isVirtualInterface(String name) {
    final lower = name.toLowerCase();
    return lower.contains('docker') ||
        lower.contains('vbox') ||
        lower.contains('vmnet') ||
        lower.contains('virbr') ||
        lower.startsWith('br-');
  }

  // ---------------------------------------------------------------------------
  // Reachability + diagnosis
  // ---------------------------------------------------------------------------

  /// Opens a TCP connection to [host]:[port] and closes it again.
  ///
  /// This is exactly the connection Najikify needs for a transfer, so a
  /// successful probe is a reliable "we are on the same network" signal. It
  /// needs no extra permission and no Najikify build on the peer.
  static Future<bool> probe(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final override = probeOverride;
    if (override != null) return override(host, port, timeout);
    if (!isValidIpv4(host)) return false;
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Decides whether [peerIp] is usable and explains precisely why not.
  ///
  /// Called before pairing and before starting a transfer, so the user sees
  /// "different network" instead of a mysterious timeout.
  static Future<PeerNetworkReport> checkPeer({
    required String peerIp,
    required int peerPort,
    String? deviceName,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final subnets = await localSubnets();

    if (await probe(peerIp, peerPort, timeout: timeout)) {
      return PeerNetworkReport(
        verdict: PeerNetworkVerdict.reachable,
        peerAddress: peerIp,
        peerPort: peerPort,
        peerName: deviceName,
        localSubnets: subnets,
      );
    }

    final verdict = subnets.isEmpty
        ? PeerNetworkVerdict.noLocalNetwork
        : (isInAnySubnet(peerIp, subnets)
            ? PeerNetworkVerdict.unreachable
            : PeerNetworkVerdict.differentNetwork);

    return PeerNetworkReport(
      verdict: verdict,
      peerAddress: peerIp,
      peerPort: peerPort,
      peerName: deviceName,
      localSubnets: subnets,
    );
  }

  /// Retrieves list of valid, non-loopback IPv4 addresses assigned to the local device.
  static Future<List<NetworkInterfaceInfo>> getLocalIpv4Interfaces() async {
    final results = <NetworkInterfaceInfo>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        // Filter out virtual/docker/vpn bridges if possible, but keep Wi-Fi and Ethernet
        for (final address in iface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            results.add(NetworkInterfaceInfo(
              name: iface.name,
              address: address.address,
              isVirtual: _isVirtualInterface(iface.name),
            ));
          }
        }
      }
    } catch (_) {
      // Fallback if permission or socket enumeration fails
    }

    // Sort physical / Wi-Fi interfaces first
    results.sort((a, b) {
      if (!a.isVirtual && b.isVirtual) return -1;
      if (a.isVirtual && !b.isVirtual) return 1;
      return 0;
    });

    return results;
  }

  /// Gets the primary local IPv4 address, or returns fallback if none found.
  static Future<String?> getPrimaryLocalIp() async {
    final interfaces = await getLocalIpv4Interfaces();
    if (interfaces.isNotEmpty) {
      return interfaces.first.address;
    }
    return null;
  }

  /// Checks if a port is currently open and available on the local machine.
  static Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class NetworkInterfaceInfo {
  final String name;
  final String address;
  final bool isVirtual;

  const NetworkInterfaceInfo({
    required this.name,
    required this.address,
    this.isVirtual = false,
  });
}
