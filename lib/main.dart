import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'services/discovery_service.dart';
import 'services/history_service.dart';
import 'services/network_service.dart';
import 'services/settings_service.dart';
import 'services/transfer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop FFI initialization for SQLite
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 1. Initialize SQLite Database & Settings
  final settingsService = SettingsService();
  await settingsService.initialize();

  // 2. Load History
  final historyService = HistoryService();
  await historyService.loadHistory();

  // 3. Determine Local Network Interfaces
  final networkService = NetworkService();
  await networkService.initialize();

  // 4. Start LocalDrop Streaming Server daemon
  final transferService = TransferService();
  await transferService.startServer();

  // 5. Start LAN Discovery Service (mDNS / UDP Multicast)
  final discoveryService = DiscoveryService();
  await discoveryService.startDiscovery();

  runApp(const LocalDropApp());
}
