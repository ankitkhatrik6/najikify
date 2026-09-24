import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/version_utils.dart';
import '../../models/app_update.dart';
import '../../services/update_service.dart';
import 'one_time_uninstall_notice.dart';

/// Dialog shown when a newer Najikify release exists.
///
/// Offers a direct download for the current platform, a link to the full
/// release page, and "Later" which remembers the skipped version.
class UpdateAvailableDialog extends StatelessWidget {
  final AppUpdate update;

  const UpdateAvailableDialog({super.key, required this.update});

  /// Shows the dialog when [update] is non-null. Safe to call from a
  /// post-frame callback.
  static Future<void> showIfAvailable(BuildContext context, AppUpdate? update) {
    if (update == null) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (_) => UpdateAvailableDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final updateService = context.read<UpdateService>();

    return AlertDialog(
      icon: Icon(Icons.system_update_alt_rounded, color: colorScheme.primary),
      title: Text('Najikify ${VersionUtils.withPrefix(update.version)} is available'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You are running ${VersionUtils.withPrefix(AppConstants.appVersion)}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (update.publishedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Released ${update.publishedAt!.year}-'
                '${update.publishedAt!.month.toString().padLeft(2, '0')}-'
                '${update.publishedAt!.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (update.assetName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        update.assetName!,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (OneTimeUninstallNotice.isNeeded()) ...[
              const SizedBox(height: 14),
              OneTimeUninstallNotice(targetVersion: update.version),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => updateService.openReleaseNotes(),
          child: const Text('Release notes'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                updateService.skipUpdate();
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await updateService.openDownload();
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download'),
            ),
          ],
        ),
      ],
    );
  }
}
