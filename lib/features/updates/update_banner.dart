import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/version_utils.dart';
import '../../services/update_service.dart';
import 'update_available_dialog.dart';

/// Compact banner shown at the top of the Home screen while a newer release is
/// available. "Update" opens the update dialog; the ✕ remembers the skipped
/// version so the banner stops nagging.
class UpdateAvailableBanner extends StatelessWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final updateService = context.watch<UpdateService>();

    if (!updateService.hasUpdate) return const SizedBox.shrink();
    final update = updateService.availableUpdate!;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update_alt_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Najikify ${VersionUtils.withPrefix(update.version)} is available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'You are on ${VersionUtils.withPrefix(AppConstants.appVersion)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => UpdateAvailableDialog.showIfAvailable(
              context,
              updateService.availableUpdate,
            ),
            child: const Text('Update'),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Not now',
            onPressed: () => updateService.skipUpdate(),
          ),
        ],
      ),
    );
  }
}
