import 'dart:io' show Platform;

/// A newer Najikify release published on GitHub.
class AppUpdate {
  final String version;
  final String tagName;
  final String releaseUrl;
  final DateTime? publishedAt;
  final String releaseNotes;

  /// Direct download URL for the artifact matching the current platform,
  /// when the release ships one (`.apk` on Android, `.deb` / `.tar.gz` on
  /// Linux). Falls back to [releaseUrl].
  final String downloadUrl;

  /// Human readable name of the matched artifact, e.g. `najikify-android-1.1.0.apk`.
  final String? assetName;

  const AppUpdate({
    required this.version,
    required this.tagName,
    required this.releaseUrl,
    required this.downloadUrl,
    this.assetName,
    this.publishedAt,
    this.releaseNotes = '',
  });

  /// Builds an [AppUpdate] from the GitHub `releases/latest` JSON payload.
  ///
  /// Returns `null` when the payload has no usable tag name, so a malformed or
  /// rate-limited response degrades silently instead of throwing.
  static AppUpdate? fromGitHubRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;

    final releaseUrl = (json['html_url'] as String?)?.trim();
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final platformAsset = _pickPlatformAsset(assets);

    DateTime? publishedAt;
    final published = json['published_at'] as String?;
    if (published != null) {
      publishedAt = DateTime.tryParse(published);
    }

    return AppUpdate(
      version: _stripTagPrefix(tag),
      tagName: tag,
      releaseUrl: releaseUrl?.isNotEmpty == true
          ? releaseUrl!
          : 'https://github.com/ankitkhatrik6/najikify/releases/tag/$tag',
      downloadUrl: (platformAsset?['browser_download_url'] as String?) ??
          releaseUrl ??
          'https://github.com/ankitkhatrik6/najikify/releases/latest',
      assetName: platformAsset?['name'] as String?,
      publishedAt: publishedAt,
      releaseNotes: (json['body'] as String?)?.trim() ?? '',
    );
  }

  static String _stripTagPrefix(String tag) {
    var value = tag.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    return value.split('+').first;
  }

  /// Picks the artifact for the running platform. Linux prefers the `.deb`
  /// and only falls back to the portable tarball when no `.deb` is published;
  /// Android prefers the universal `.apk` over the per-architecture ones.
  static Map<String, dynamic>? _pickPlatformAsset(
    List<Map<String, dynamic>> assets,
  ) {
    if (assets.isEmpty) return null;

    bool matches(Map<String, dynamic> asset, List<String> extensions) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      return extensions.any(name.endsWith);
    }

    final preferred = <List<String>>[
      if (Platform.isAndroid) ['.apk'],
      if (Platform.isLinux) ['.deb', '.tar.gz'],
      if (Platform.isWindows) ['.zip', '.exe'],
      if (Platform.isMacOS) ['.dmg', '.zip'],
    ];

    for (final extensions in preferred) {
      final candidates =
          assets.where((asset) => matches(asset, extensions)).toList();
      if (candidates.isEmpty) continue;

      if (Platform.isAndroid) {
        // Releases ship a universal APK plus smaller per-architecture APKs
        // (arm64-v8a / armeabi-v7a). The universal one always installs, so it
        // is the default download; the ABI-specific files stay available from
        // the release page when a smaller download is wanted. GitHub does not
        // guarantee asset ordering, hence the explicit filter.
        return candidates.firstWhere(
          (asset) => !_abiSuffix.hasMatch(asset['name'] as String? ?? ''),
          orElse: () => candidates.first,
        );
      }
      return candidates.first;
    }
    return null;
  }

  /// Matches the architecture suffix of the per-ABI Android artifacts, e.g.
  /// `najikify-android-1.0.7-arm64-v8a.apk`. The universal APK
  /// (`najikify-android-1.0.7.apk`) does not match.
  static final RegExp _abiSuffix = RegExp(
    r'-(arm64-v8a|armeabi-v7a|x86_64|x86)\.apk$',
    caseSensitive: false,
  );

  @override
  String toString() => 'AppUpdate($version, asset: $assetName)';
}
