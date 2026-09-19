import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onSendPressed;
  final VoidCallback? onToggleTrust;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onSendPressed,
    this.onToggleTrust,
    this.onTap,
  });

  IconData _getPlatformIcon(DevicePlatform platform) {
    switch (platform) {
      case DevicePlatform.linux:
        return Icons.computer;
      case DevicePlatform.android:
        return Icons.phone_android;
      case DevicePlatform.windows:
        return Icons.desktop_windows;
      case DevicePlatform.macos:
        return Icons.laptop_mac;
      case DevicePlatform.ios:
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: device.isTrusted
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ?? onSendPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Platform Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getPlatformIcon(device.platform),
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Device Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.isTrusted) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            color: colorScheme.primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${device.platform.displayName} • ${device.ipAddress}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action Button
              FilledButton.tonal(
                onPressed: onSendPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Send'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
