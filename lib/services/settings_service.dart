import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/crypto_utils.dart';
import '../models/app_settings.dart';
import '../models/device.dart';
import 'database_service.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final DatabaseService _db = DatabaseService();

  late String _deviceId;
  late String _fingerprint;
  late AppSettings _settings;
  bool _isInitialized = false;

  String get deviceId => _deviceId;
  String get fingerprint => _fingerprint;
  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  DevicePlatform get currentPlatform {
    if (Platform.isLinux) return DevicePlatform.linux;
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isMacOS) return DevicePlatform.macos;
    if (Platform.isIOS) return DevicePlatform.ios;
    return DevicePlatform.unknown;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load or generate persistent Device ID
    var storedId = await _db.getSetting('device_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await _db.setSetting('device_id', storedId);
    }
    _deviceId = storedId;
    _fingerprint = CryptoUtils.sha256Digest('najikify-$_deviceId').substring(0, 32);

    // Determine default download path for Linux vs Android
    final defaultDownloadDir = await _getDefaultDownloadDirectory();

    // Load stored settings or use default
    final storedName = await _db.getSetting('device_name');
    final storedTheme = await _db.getSetting('theme_mode');
    final storedDownloadPath = await _db.getSetting('download_path');
    final storedAsk = await _db.getSetting('ask_before_receiving');
    final storedAutoAccept = await _db.getSetting('auto_accept_trusted');
    final storedPort = await _db.getSetting('server_port');

    final fallbackDeviceName = _generateDefaultDeviceName();

    _settings = AppSettings(
      deviceName: (storedName != null && storedName.isNotEmpty) ? storedName : fallbackDeviceName,
      themeMode: _parseThemeMode(storedTheme),
      downloadPath: (storedDownloadPath != null && storedDownloadPath.isNotEmpty)
          ? storedDownloadPath
          : defaultDownloadDir,
      askBeforeReceiving: storedAsk == null || storedAsk == '1',
      autoAcceptTrusted: storedAutoAccept == null || storedAutoAccept == '1',
      serverPort: storedPort != null ? int.tryParse(storedPort) ?? 53317 : 53317,
    );

    _isInitialized = true;
    notifyListeners();
  }

  String _generateDefaultDeviceName() {
    final hostname = Platform.localHostname;
    final platformName = currentPlatform.displayName;
    if (hostname.isNotEmpty && !hostname.toLowerCase().contains('localhost')) {
      return '$hostname ($platformName)';
    }
    return '$platformName Device';
  }

  Future<String> _getDefaultDownloadDirectory() async {
    try {
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          final linuxDownloads = p.join(home, 'Downloads', AppConstants.defaultSubdirectory);
          final dir = Directory(linuxDownloads);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return linuxDownloads;
        }
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final target = p.join(downloadsDir.path, AppConstants.defaultSubdirectory);
        final dir = Directory(target);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return target;
      }

      final appDocs = await getApplicationDocumentsDirectory();
      final fallback = p.join(appDocs.path, AppConstants.defaultSubdirectory);
      final dir = Directory(fallback);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return fallback;
    } catch (_) {
      return '/tmp/${AppConstants.defaultSubdirectory}';
    }
  }

  ThemeMode _parseThemeMode(String? val) {
    if (val == 'light') return ThemeMode.light;
    if (val == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> updateDeviceName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    _settings = _settings.copyWith(deviceName: trimmed);
    await _db.setSetting('device_name', trimmed);
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _db.setSetting('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> updateDownloadPath(String path) async {
    _settings = _settings.copyWith(downloadPath: path);
    await _db.setSetting('download_path', path);
    notifyListeners();
  }

  Future<void> updateAskBeforeReceiving(bool val) async {
    _settings = _settings.copyWith(askBeforeReceiving: val);
    await _db.setSetting('ask_before_receiving', val ? '1' : '0');
    notifyListeners();
  }

  Future<void> updateAutoAcceptTrusted(bool val) async {
    _settings = _settings.copyWith(autoAcceptTrusted: val);
    await _db.setSetting('auto_accept_trusted', val ? '1' : '0');
    notifyListeners();
  }

  Device get selfDevice => Device(
        id: _deviceId,
        name: _settings.deviceName,
        platform: currentPlatform,
        ipAddress: '',
        port: _settings.serverPort,
        fingerprint: _fingerprint,
        isTrusted: true,
        lastSeen: DateTime.now(),
      );
}
