import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/version_utils.dart';
import '../../models/device.dart';
import '../../services/database_service.dart';
import '../../services/network_service.dart';
import '../../services/settings_service.dart';
import '../../services/update_service.dart';
import '../../widgets/app_logo.dart';
import '../updates/update_available_dialog.dart';
import 'about_najikify_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Device> _trustedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadTrustedDevices();
  }

  Future<void> _loadTrustedDevices() async {
    final list = await _db.getTrustedDevices();
    if (mounted) {
      setState(() => _trustedDevices = list);
    }
  }

  void _showEditDeviceNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Device Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            hintText: "e.g. Ankit's Laptop",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<SettingsService>().updateDeviceName(newName);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDownloadPath(BuildContext context) async {
    final selectedDirectory = await getDirectoryPath();
    if (selectedDirectory != null && context.mounted) {
      await context.read<SettingsService>().updateDownloadPath(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsService = context.watch<SettingsService>();
    final networkService = context.watch<NetworkService>();
    final settings = settingsService.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Section: Device
          _buildSectionHeader(context, 'Device Identity'),
          ListTile(
            title: const Text('Device Name'),
            subtitle: Text(settings.deviceName),
            leading: const Icon(Icons.badge_outlined),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () => _showEditDeviceNameDialog(context, settings.deviceName),
          ),
          ListTile(
            title: const Text('Platform'),
            subtitle: Text(settingsService.currentPlatform.displayName),
            leading: Icon(
              settingsService.currentPlatform == DevicePlatform.linux
                  ? Icons.computer
                  : Icons.phone_android,
            ),
          ),
          ListTile(
            title: const Text('Device Fingerprint'),
            subtitle: Text(
              settingsService.fingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            leading: const Icon(Icons.fingerprint_rounded),
          ),

          const Divider(),

          // Section: Appearance
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_getThemeName(settings.themeMode)),
            leading: const Icon(Icons.palette_outlined),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  settingsService.updateThemeMode(mode);
                }
              },
            ),
          ),

          const Divider(),

          // Section: Transfers
          _buildSectionHeader(context, 'Transfers & Storage'),
          ListTile(
            title: const Text('Download Location'),
            subtitle: Text(settings.downloadPath),
            leading: const Icon(Icons.folder_open_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickDownloadPath(context),
          ),
          SwitchListTile(
            title: const Text('Ask before receiving'),
            subtitle: const Text('Always show confirmation prompt for transfers'),
            value: settings.askBeforeReceiving,
            secondary: const Icon(Icons.security_outlined),
            onChanged: (val) => settingsService.updateAskBeforeReceiving(val),
          ),
          SwitchListTile(
            title: const Text('Auto-accept from trusted devices'),
            subtitle: const Text('Skip confirmation if sender is in trusted devices'),
            value: settings.autoAcceptTrusted,
            secondary: const Icon(Icons.verified_user_outlined),
            onChanged: (val) => settingsService.updateAutoAcceptTrusted(val),
          ),

          const Divider(),

          // Section: Network
          _buildSectionHeader(context, 'Network & Interfaces'),
          ListTile(
            title: const Text('Local IP Address'),
            subtitle: Text(networkService.currentIp ?? 'No local IP (disconnected)'),
            leading: const Icon(Icons.network_wifi_outlined),
          ),
          ListTile(
            title: const Text('Local Server Port'),
            subtitle: Text('${settings.serverPort} (TCP HTTP Streaming)'),
            leading: const Icon(Icons.lan_outlined),
          ),

          const Divider(),

          // Section: Security & Trusted Devices
          _buildSectionHeader(context, 'Trusted Devices'),
          if (_trustedDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No trusted devices. Devices can be trusted after QR pairing or manual verification.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            ..._trustedDevices.map(
              (d) => ListTile(
                title: Text(d.name),
                subtitle: Text('${d.platform.displayName} • ${d.ipAddress}'),
                leading: const Icon(Icons.verified, color: Colors.blue),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  tooltip: 'Revoke trust',
                  onPressed: () async {
                    await _db.updateDeviceTrust(d.id, false);
                    _loadTrustedDevices();
                  },
                ),
              ),
            ),

          const Divider(),

          // Section: About
          _buildSectionHeader(context, 'About Najikify'),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('${AppConstants.appVersion} (Offline LAN Peer-to-Peer)'),
            leading: Icon(Icons.info_outline),
          ),
          _buildUpdateTile(context),
          ListTile(
            title: const Text('About Najikify'),
            subtitle: const Text(
              'What Najikify is, how it works and how to support it',
            ),
            leading: const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: AppLogo(size: 36, borderRadius: 10)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AboutNajikifyScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('Open Source Licenses'),
            subtitle: const Text('View licenses for third-party libraries'),
            leading: const Icon(Icons.description_outlined),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            ),
          ),
        ],
      ),
    );
  }

  /// "Check for updates" entry: shows the current state and lets the user
  /// trigger a check on demand (the automatic check runs at most every 6 hours).
  Widget _buildUpdateTile(BuildContext context) {
    final updateService = context.watch<UpdateService>();
    final update = updateService.availableUpdate;

    String subtitle;
    if (updateService.isChecking) {
      subtitle = 'Checking GitHub for a newer version...';
    } else if (update != null) {
      subtitle = 'Najikify ${VersionUtils.withPrefix(update.version)} is available';
    } else if (updateService.lastError != null) {
      subtitle = updateService.lastError!;
    } else if (updateService.lastCheckedAt != null) {
      subtitle = 'Up to date • checked ${FormatUtils.formatDateTime(updateService.lastCheckedAt!)}';
    } else {
      subtitle = 'You are on the latest version';
    }

    return ListTile(
      title: const Text('Check for Updates'),
      subtitle: Text(subtitle),
      leading: Icon(
        update != null
            ? Icons.system_update_alt_rounded
            : Icons.cloud_download_outlined,
        color: update != null ? Theme.of(context).colorScheme.primary : null,
      ),
      trailing: updateService.isChecking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (update != null
              ? const Icon(Icons.chevron_right_rounded)
              : const Icon(Icons.refresh_rounded, size: 20)),
      onTap: updateService.isChecking
          ? null
          : () async {
              if (update != null) {
                await UpdateAvailableDialog.showIfAvailable(context, update);
                return;
              }
              final result = await updateService.checkForUpdates(force: true);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result != null
                        ? 'Najikify ${VersionUtils.withPrefix(result.version)} is available'
                        : (updateService.lastError ??
                            'You are on the latest version (${AppConstants.appVersion})'),
                  ),
                ),
              );
            },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System default';
    }
  }
}
