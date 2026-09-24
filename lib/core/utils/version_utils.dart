/// Semantic-version helpers used by the update checker.
///
/// Releases are tagged `v<major>.<minor>.<patch>` (for example `v1.1.0`) while
/// [AppConstants.appVersion] is the bare `1.1.0`. Both forms, plus any build
/// metadata (`1.0.3+4`), are accepted here.
class VersionUtils {
  VersionUtils._();

  /// Strips a leading `v`/`V`, build metadata (`+4`) and prerelease tags
  /// (`-beta.1`) from [version] and splits the numeric core into integers.
  ///
  /// Missing or non-numeric segments become `0`, so `1.1` == `1.1.0` and a
  /// malformed tag never throws.
  static List<int> parse(String version) {
    var cleaned = version.trim();
    if (cleaned.isEmpty) return const [0, 0, 0];

    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }

    // Drop build metadata and prerelease suffixes.
    cleaned = cleaned.split('+').first;
    cleaned = cleaned.split('-').first;

    final parts = cleaned.split('.');
    final numbers = <int>[];
    for (var i = 0; i < 3; i++) {
      final part = i < parts.length ? parts[i].trim() : '';
      numbers.add(int.tryParse(part) ?? 0);
    }
    return numbers;
  }

  /// Returns a negative number if [a] < [b], `0` if they are equal and a
  /// positive number if [a] > [b].
  static int compare(String a, String b) {
    final left = parse(a);
    final right = parse(b);
    for (var i = 0; i < 3; i++) {
      final diff = left[i] - right[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// True when [candidate] is strictly newer than [current].
  static bool isNewer(String candidate, String current) =>
      compare(candidate, current) > 0;

  /// Normalises any accepted form to `major.minor.patch`.
  static String normalize(String version) => parse(version).join('.');

  /// Formats a version for display as `v1.1.0`.
  static String withPrefix(String version) => 'v${normalize(version)}';
}
