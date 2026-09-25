import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/notification_gateway.dart';
import '../../widgets/app_logo.dart';
import 'support_momo_dialog.dart';
/// Full "About Us" page for Najikify, reached from Settings → About Najikify.
///
/// Describes what Najikify is, how it works, its key features, and how to
/// support the project — with the proper logo on both Linux and Android.
class AboutNajikifyScreen extends StatelessWidget {
  const AboutNajikifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About Najikify')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Column(
              children: [
                const AppLogo(size: 96, borderRadius: 24),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConstants.appVersion} • by ${AppConstants.appAuthor}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Private peer-to-peer file transfer for your local network. '
            'Move files and folders directly between Linux desktops and '
            'Android devices — no cloud, no accounts, no third-party uploads. '
            'Your data never leaves your Wi-Fi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _AboutSection(
            title: 'How it works',
            children: [
              _AboutBullet(
                  'Devices find each other automatically on the same Wi-Fi or LAN.'),
              _AboutBullet('Optionally pair with a QR code for trusted devices.'),
              _AboutBullet(
                  'Files stream directly device-to-device with checksum verification.'),
              _AboutBullet('Progress, speed and ETA update live on both ends.'),
              _AboutBullet(
                  'Every transfer is recorded in a local history on each device.'),
            ],
          ),
          const SizedBox(height: 16),
          const _AboutSection(
            title: 'Highlights',
            children: [
              _AboutBullet(
                  'Cross-platform: Linux desktop and Android from one codebase.'),
              _AboutBullet(
                  'No sign-up, no server in the middle, nothing uploaded anywhere.'),
              _AboutBullet(
                  'In-app update checks with system notifications on both platforms.'),
              _AboutBullet(
                  'Free and open source (MIT) — contributions welcome.'),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => SupportMomoDialog.show(context),
            icon: const Icon(Icons.ramen_dining_rounded, size: 18),
            label: const Text(
              'Support us - Buy me a Momo',
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => NotificationGateway().openExternal(
              AppConstants.githubRepoUrl,
            ),
            icon: const Icon(Icons.code_rounded, size: 18),
            label: const Text(
              'View source and releases',
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            ),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Open source licenses'),
          ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AboutSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _AboutBullet extends StatelessWidget {
  final String text;

  const _AboutBullet(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
