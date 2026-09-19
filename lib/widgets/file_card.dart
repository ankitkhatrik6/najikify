import 'package:flutter/material.dart';
import '../core/utils/format_utils.dart';
import '../models/transfer_file.dart';

class FileCard extends StatelessWidget {
  final TransferFile file;
  final VoidCallback? onRemove;

  const FileCard({
    super.key,
    required this.file,
    this.onRemove,
  });

  IconData _getFileIcon(String fileName, bool isFolder) {
    if (isFolder) return Icons.folder_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'avi':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'flac':
      case 'wav':
      case 'm4a':
        return Icons.audio_file_rounded;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return Icons.archive_rounded;
      case 'apk':
      case 'deb':
        return Icons.inventory_2_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(file.name, file.isFolder),
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FormatUtils.formatBytes(file.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}
