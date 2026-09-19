import 'package:flutter/material.dart';
import '../core/utils/file_utils.dart';

class FileConflictDialog extends StatefulWidget {
  final String fileName;
  final bool hasMultipleFiles;

  const FileConflictDialog({
    super.key,
    required this.fileName,
    this.hasMultipleFiles = false,
  });

  @override
  State<FileConflictDialog> createState() => _FileConflictDialogState();
}

class _FileConflictDialogState extends State<FileConflictDialog> {
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('File already exists'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fileName,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('A file with this name already exists in the destination folder. How would you like to proceed?'),
          if (widget.hasMultipleFiles) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _applyToAll,
              onChanged: (val) {
                setState(() {
                  _applyToAll = val ?? false;
                });
              },
              title: const Text('Apply to all remaining conflicts'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(FileConflictResolution(action: FileConflictAction.skip, applyToAll: _applyToAll)),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(FileConflictResolution(action: FileConflictAction.replace, applyToAll: _applyToAll)),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(FileConflictResolution(action: FileConflictAction.keepBoth, applyToAll: _applyToAll)),
          child: const Text('Keep both'),
        ),
      ],
    );
  }
}

class FileConflictResolution {
  final FileConflictAction action;
  final bool applyToAll;

  const FileConflictResolution({
    required this.action,
    required this.applyToAll,
  });
}
