import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../../models/device.dart';
import '../../models/transfer_file.dart';

class IncomingTransferDialog extends StatelessWidget {
  final Device sender;
  final List<TransferFile> files;
  final int totalBytes;
  final String savePath;

  const IncomingTransferDialog({
    super.key,
    required this.sender,
    required this.files,
    required this.totalBytes,
    required this.savePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.download_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Text('Incoming Transfer'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: [
                  TextSpan(
                    text: sender.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' wants to send:'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    '${files.length} ${files.length == 1 ? 'file' : 'files'} • ${FormatUtils.formatBytes(totalBytes)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Save to:',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              savePath,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
