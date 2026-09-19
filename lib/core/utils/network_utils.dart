import 'dart:io';

class NetworkUtils {
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
              isVirtual: iface.name.toLowerCase().contains('docker') ||
                  iface.name.toLowerCase().contains('vbox') ||
                  iface.name.toLowerCase().contains('vmnet'),
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
