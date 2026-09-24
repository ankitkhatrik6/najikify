import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Explains the one-time uninstall needed when coming from a build that was
/// signed with the Android debug key (1.0.2 and older).
///
/// Android refuses to replace an installed app with one signed by a different
/// key, so those users must uninstall once. Every release from 1.0.3 onwards
/// shares one stable release key, so this notice disappears on its own as soon
/// as the running version is newer than [AppConstants.lastDebugSignedVersion].
class OneTimeUninstallNotice extends StatelessWidget {
  final String targetVersion;

  const OneTimeUninstallNotice({super.key, required this.targetVersion});

  /// True when the running build is one of the debug-signed ones, i.e. when the
  /// notice is relevant.
  static bool isNeeded() {
    const current = AppConstants.appVersion;
    const last = AppConstants.lastDebugSignedVersion;
    // Compare numerically so "1.0.10" is still treated as newer than "1.0.2".
    final currentParts = current.split('.').map(int.tryParse).toList();
    final lastParts = last.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final a = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      final b = (i < lastParts.length ? lastParts[i] : 0) ?? 0;
      if (a != b) return a < b;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'One-time step on Android',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Builds up to ${AppConstants.lastDebugSignedVersion} were signed with '
            'a test key, so Android refuses to install over them ("app not '
            'installed as package conflicts with an existing package"). '
            'Uninstall Najikify once, install $targetVersion, and every later '
            'update installs normally.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
