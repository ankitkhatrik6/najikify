import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/file_utils.dart';
import '../../models/device.dart';
import '../../services/discovery_service.dart';
import '../../services/network_service.dart';
import '../../services/settings_service.dart';
import '../../services/transfer_service.dart';
import '../../widgets/device_card.dart';
import '../../widgets/empty_state.dart';
import '../pairing/qr_display_dialog.dart';
import '../pairing/qr_scanner_screen.dart';
import '../updates/update_banner.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDragging = false;

  Future<void> _pickAndSendFiles(BuildContext context, Device targetDevice) async {
    final transferService = context.read<TransferService>();

    // Show choice: Send Files or Send Folder
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_present_rounded),
              title: const Text('Send Files'),
              subtitle: const Text('Select one or multiple files'),
              onTap: () => Navigator.of(ctx).pop('files'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('Send Folder'),
              subtitle: const Text('Select an entire directory to transfer'),
              onTap: () => Navigator.of(ctx).pop('folder'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    List<FileEntityEntry> entriesToSend = [];

    if (choice == 'files') {
      const typeGroup = XTypeGroup(label: 'files');
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      for (final xf in files) {
        final f = File(xf.path);
        final size = await f.length();
        entriesToSend.add(FileEntityEntry(
          file: f,
          relativePath: xf.name,
          size: size,
          isFolder: false,
        ));
      }
    } else if (choice == 'folder') {
      final selectedDir = await getDirectoryPath();
      if (selectedDir != null) {
        final dir = Directory(selectedDir);
        entriesToSend = await FileUtils.listDirectoryFiles(dir);
      }
    }

    if (entriesToSend.isNotEmpty) {
      await transferService.sendFiles(
        peerDevice: targetDevice,
        entries: entriesToSend,
      );

      // Navigate to Transfers tab to watch live progress
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(1);
      }
    }
  }

  void _onConnectDevicePressed(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect Device',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Share your code or scan a peer code — works both ways.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded),
              title: const Text('Show my QR code'),
              subtitle: const Text('Let the other device scan this device'),
              onTap: () {
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (_) => const QrDisplayDialog(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Scan peer QR code'),
              subtitle: const Text('Camera, image file or pasted link'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final settings = context.watch<SettingsService>();
    final network = context.watch<NetworkService>();
    final discovery = context.watch<DiscoveryService>();
    final transferService = context.watch<TransferService>();

    final devices = discovery.discoveredDevices;
    final activeCount = transferService.activeTransfers.length;

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        final dropped = <FileEntityEntry>[];
        for (final item in details.files) {
          final file = File(item.path);
          if (await FileSystemEntity.isDirectory(item.path)) {
            final dirEntries = await FileUtils.listDirectoryFiles(Directory(item.path));
            dropped.addAll(dirEntries);
          } else {
            final length = await file.length();
            dropped.add(FileEntityEntry(
              file: file,
              relativePath: item.name,
              size: length,
            ));
          }
        }

        if (dropped.isNotEmpty && devices.isNotEmpty) {
          // Show bottom sheet to select which device to send to
          if (context.mounted) {
            _showTargetDevicePicker(context, dropped);
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar / Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Najikify',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    settings.currentPlatform == DevicePlatform.linux
                                        ? Icons.computer
                                        : Icons.phone_android,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    settings.settings.deviceName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Connection Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: network.isConnected
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : colorScheme.errorContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: network.isConnected
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : colorScheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: network.isConnected ? Colors.green : colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  network.isConnected ? (network.currentIp ?? 'Connected') : 'No Wi-Fi',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: network.isConnected ? Colors.green.shade800 : colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Active Transfers Banner (if any)
                      if (activeCount > 0) ...[
                        InkWell(
                          onTap: () => widget.onNavigateTab?.call(1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '$activeCount transfer in progress...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: colorScheme.onPrimaryContainer),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Update available banner (renders nothing when the app
                      // is up to date)
                      const UpdateAvailableBanner(),

                      // Section Title & Connect Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Devices nearby',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                onPressed: () {
                                  discovery.sendProbe();
                                  network.refreshNetwork();
                                },
                                tooltip: 'Refresh Devices',
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: () => _onConnectDevicePressed(context),
                                icon: const Icon(Icons.qr_code_rounded, size: 18),
                                label: const Text('Connect Device'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Drag and drop overlay banner (Linux desktop)
              if (_isDragging)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.primary, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.file_download_rounded, size: 40, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Drop files here to transfer',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Nearby Devices List or Empty State
              if (devices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'No devices found',
                    message: 'Make sure Najikify is open on other devices connected to this Wi-Fi network.',
                    actionLabel: 'Scan with QR Code',
                    onAction: () => _onConnectDevicePressed(context),
                    isScanning: discovery.isDiscovering,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final device = devices[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DeviceCard(
                            device: device,
                            onSendPressed: () => _pickAndSendFiles(context, device),
                            onToggleTrust: () => discovery.toggleTrust(device),
                          ),
                        );
                      },
                      childCount: devices.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTargetDevicePicker(BuildContext context, List<FileEntityEntry> entries) {
    final discovery = context.read<DiscoveryService>();
    final transferService = context.read<TransferService>();
    final devices = discovery.discoveredDevices;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Send ${entries.length} ${entries.length == 1 ? 'file' : 'files'} to:',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ...devices.map(
                (d) => ListTile(
                  leading: const Icon(Icons.devices_rounded),
                  title: Text(d.name),
                  subtitle: Text('${d.platform.displayName} • ${d.ipAddress}'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    transferService.sendFiles(peerDevice: d, entries: entries);
                    widget.onNavigateTab?.call(1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
