import 'package:flutter/material.dart';

class AppSettings {
  final String deviceName;
  final ThemeMode themeMode;
  final String downloadPath;
  final bool askBeforeReceiving;
  final bool autoAcceptTrusted;
  final int maxConcurrentTransfers;
  final int serverPort;

  const AppSettings({
    required this.deviceName,
    this.themeMode = ThemeMode.system,
    required this.downloadPath,
    this.askBeforeReceiving = true,
    this.autoAcceptTrusted = true,
    this.maxConcurrentTransfers = 3,
    this.serverPort = 53317,
  });

  AppSettings copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    String? downloadPath,
    bool? askBeforeReceiving,
    bool? autoAcceptTrusted,
    int? maxConcurrentTransfers,
    int? serverPort,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themeMode: themeMode ?? this.themeMode,
      downloadPath: downloadPath ?? this.downloadPath,
      askBeforeReceiving: askBeforeReceiving ?? this.askBeforeReceiving,
      autoAcceptTrusted: autoAcceptTrusted ?? this.autoAcceptTrusted,
      maxConcurrentTransfers: maxConcurrentTransfers ?? this.maxConcurrentTransfers,
      serverPort: serverPort ?? this.serverPort,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_name': deviceName,
      'theme_mode': themeMode.name,
      'download_path': downloadPath,
      'ask_before_receiving': askBeforeReceiving ? 1 : 0,
      'auto_accept_trusted': autoAcceptTrusted ? 1 : 0,
      'max_concurrent_transfers': maxConcurrentTransfers,
      'server_port': serverPort,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map, String defaultDownloadPath) {
    ThemeMode mode;
    switch (map['theme_mode']) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      default:
        mode = ThemeMode.system;
    }

    return AppSettings(
      deviceName: map['device_name'] as String? ?? 'LocalDrop Device',
      themeMode: mode,
      downloadPath: (map['download_path'] as String?)?.isNotEmpty == true
          ? map['download_path'] as String
          : defaultDownloadPath,
      askBeforeReceiving: (map['ask_before_receiving'] as int? ?? 1) == 1,
      autoAcceptTrusted: (map['auto_accept_trusted'] as int? ?? 1) == 1,
      maxConcurrentTransfers: map['max_concurrent_transfers'] as int? ?? 3,
      serverPort: map['server_port'] as int? ?? 53317,
    );
  }
}
