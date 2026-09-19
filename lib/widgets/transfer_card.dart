import 'package:flutter/material.dart';
import '../core/utils/format_utils.dart';
import '../models/transfer.dart';

class TransferCard extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TransferCard({
    super.key,
    required this.transfer,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSend = transfer.direction == TransferDirection.send;
    final isActive = transfer.state.isActive;

    final currentFile = transfer.currentFile;
    final fileNameDisplay = currentFile != null ? currentFile.name : (transfer.files.isNotEmpty ? transfer.files.first.name : 'Files');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Direction icon, Target Device, Status / Actions
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSend
                        ? colorScheme.primaryContainer.withValues(alpha: 0.6)
                        : colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isSend ? colorScheme.onPrimaryContainer : colorScheme.onSecondaryContainer,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSend
                            ? 'Sending to ${transfer.peerDevice.name}'
                            : 'Receiving from ${transfer.peerDevice.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fileNameDisplay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isActive && onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onCancel,
                    tooltip: 'Cancel Transfer',
                  )
                else if (transfer.state == TransferState.failed && onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  )
                else
                  _buildStatusChip(context, transfer.state),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: transfer.state == TransferState.connecting ? null : transfer.progress,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  transfer.state == TransferState.failed
                      ? colorScheme.error
                      : transfer.state == TransferState.completed
                          ? Colors.green
                          : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Stats row: Bytes / Total & Speed / ETA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FormatUtils.formatBytes(transfer.transferredBytes)} / ${FormatUtils.formatBytes(transfer.totalBytes)} • ${transfer.progressPercent}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActive && transfer.speed > 0)
                  Text(
                    '${FormatUtils.formatSpeed(transfer.speed)} • ${FormatUtils.formatEta(transfer.etaSeconds)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (transfer.totalFiles > 1)
                  Text(
                    '${transfer.currentFileIndex + 1} / ${transfer.totalFiles} files',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    FormatUtils.formatDateTime(transfer.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, TransferState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bg;
    Color fg;
    String label;

    switch (state) {
      case TransferState.completed:
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade700;
        label = 'Completed';
        break;
      case TransferState.failed:
        bg = colorScheme.errorContainer;
        fg = colorScheme.onErrorContainer;
        label = 'Failed';
        break;
      case TransferState.cancelled:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.onSurfaceVariant;
        label = 'Cancelled';
        break;
      default:
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
        label = state.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
