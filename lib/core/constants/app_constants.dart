/// Global application constants for Najikify.
///
/// NOTE: [appVersion] is the single source of truth for the version string
/// shown in Settings and the license page. It MUST match pubspec.yaml.
/// Keep it in sync whenever the release version is bumped.
class AppConstants {
  static const String appName = 'Najikify';
  static const String appVersion = '1.0.8';
  static const String appAuthor = 'Ankit Khatri KC';
  static const String githubRepoUrl = 'https://github.com/ankitkhatrik6/najikify';

  /// GitHub Releases API used by the in-app update checker.
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/ankitkhatrik6/najikify/releases/latest';

  /// Star the repo — used by the "Do you like Najikify?" prompt.
  static const String githubStarUrl =
      'https://github.com/ankitkhatrik6/najikify';

  /// Last release that was signed with the Android **debug** key. Installs of
  /// these builds cannot be upgraded in place (Android refuses to replace an
  /// app with a differently signed package), so the update flow mentions the
  /// one-time uninstall. Every release from 1.0.3 onwards shares one stable
  /// release key and updates normally.
  static const String lastDebugSignedVersion = '1.0.2';

  // Storage keys & database constants
  static const String databaseName = 'najikify.db';
  static const int databaseVersion = 1;
  static const String defaultSubdirectory = 'Najikify';

  // Transfer limits
  static const int defaultChunkSize = 64 * 1024; // 64 KB per stream chunk
  static const int maxConcurrentTransfers = 3;
  static const Duration transferTimeout = Duration(seconds: 45);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration pairingSessionExpiry = Duration(minutes: 5);
}
