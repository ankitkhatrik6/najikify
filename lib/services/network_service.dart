import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/network_utils.dart';

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  List<NetworkInterfaceInfo> _interfaces = [];
  String? _currentIp;
  bool _isConnected = false;
  Timer? _pollingTimer;

  List<NetworkInterfaceInfo> get interfaces => _interfaces;
  String? get currentIp => _currentIp;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    await refreshNetwork();
    // Periodically verify network interface changes (e.g. Wi-Fi reconnected, IP changed)
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => refreshNetwork());
  }

  Future<void> refreshNetwork() async {
    final interfaces = await NetworkUtils.getLocalIpv4Interfaces();
    final primaryIp = interfaces.isNotEmpty ? interfaces.first.address : null;

    final hasChanged = _currentIp != primaryIp || _interfaces.length != interfaces.length;

    _interfaces = interfaces;
    _currentIp = primaryIp;
    _isConnected = primaryIp != null && primaryIp.isNotEmpty;

    if (hasChanged) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
