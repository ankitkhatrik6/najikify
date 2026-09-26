import 'package:flutter/material.dart';

import '../core/errors/app_exceptions.dart';
import '../core/errors/error_handler.dart';

/// Explains *why* a pairing or transfer attempt cannot work and what to do
/// about it.
///
/// Its main job is the cross-network case: when two devices sit on different
/// Wi-Fi networks (or one of them is on mobile data) Najikify says so
/// explicitly — naming both networks — instead of failing with a timeout.
class NetworkIssueDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? peerNetwork;
  final String? localNetwork;

  const NetworkIssueDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.wifi_tethering_error_rounded,
    this.peerNetwork,
    this.localNetwork,
  });

  /// Presents the wording that fits [error] — a cross-network peer, a device
  /// without any local address, an address that now answers as someone else,
  /// or a generic failure.
  static Future<void> show(BuildContext context, Object error) async {
    String title;
    IconData icon;
    if (error is DifferentNetworkException) {
      title = 'Different network detected';
      icon = Icons.sync_problem_rounded;
    } else if (error is NetworkUnavailableException) {
      title = 'No local network';
      icon = Icons.wifi_off_rounded;
    } else if (error is PeerIdentityMismatchException) {
      title = 'Not the device you paired with';
      icon = Icons.phonelink_erase_rounded;
    } else {
      title = 'Transfer failed';
      icon = Icons.error_outline_rounded;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => NetworkIssueDialog(
        title: title,
        icon: icon,
        message: error is NajikifyException
            ? error.message
            : ErrorHandler.getUserFriendlyMessage(error),
        peerNetwork:
            error is DifferentNetworkException ? error.peerNetwork : null,
        localNetwork:
            error is DifferentNetworkException ? error.localNetwork : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasNetworks = peerNetwork != null || localNetwork != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(icon, size: 34, color: colorScheme.error),
      title: Text(title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.bodyMedium),
            if (hasNetworks) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (localNetwork != null)
                      _NetworkRow(
                        label: 'This device',
                        value: localNetwork!,
                        color: colorScheme.primary,
                      ),
                    if (localNetwork != null && peerNetwork != null)
                      const SizedBox(height: 6),
                    if (peerNetwork != null)
                      _NetworkRow(
                        label: 'Other device',
                        value: peerNetwork!,
                        color: colorScheme.error,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'How to fix it',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const _CheckLine('Connect both devices to the same Wi-Fi router'),
            const _CheckLine('Or turn on a hotspot on one device and join it from the other'),
            const _CheckLine('Avoid guest/isolated networks that block device-to-device traffic'),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _NetworkRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NetworkRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chevron_right_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}