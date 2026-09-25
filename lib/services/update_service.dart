import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/utils/version_utils.dart';
import '../models/app_update.dart';
import 'database_service.dart';
import 'notification_gateway.dart';

/// Polls the GitHub Releases API for a newer Najikify build and tells the rest
/// of the app about it.
///
/// Behaviour:
/// * Automatic checks are throttled to one every [checkInterval] so launching
///   the app repeatedly does not spam the GitHub API (60 unauthenticated
///   requests/hour are allowed per IP).
/// * On Android a native periodic job (`UpdateCheckJobService`, armed through
///   [NotificationGateway.scheduleBackgroundUpdateChecks]) runs the same check
///   in the background, so the system notification appears even when the app is
///   closed. Both paths share the "already announced" version.
/// * A system notification is posted at most once per discovered version, so an
///   update the user already ignored does not keep popping up.
/// * Every network failure is swallowed into [lastError]; the app works fully
///   offline and simply reports that the check could not be completed.
class UpdateService extends ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// How long to wait between automatic checks.
  static const Duration checkInterval = Duration(hours: 6);

  static const String _lastCheckKey = 'update_last_check_ms';
  static const String _notifiedVersionKey = 'update_notified_version';
  static const String _skippedVersionKey = 'update_skipped_version';

  final DatabaseService _db = DatabaseService();
  final NotificationGateway _notifications = NotificationGateway();

  /// Injectable for tests; defaults to the real client.
  http.Client? httpClientOverride;

  AppUpdate? _availableUpdate;
  bool _isChecking = false;
  bool _isInitialized = false;
  String? _lastError;
  DateTime? _lastCheckedAt;
  String? _notifiedVersion;
  String? _skippedVersion;

  /// The newer release, or `null` when the app is up to date.
  AppUpdate? get availableUpdate => _availableUpdate;

  /// True when a newer release has been found and the user has not skipped it.
  bool get hasUpdate =>
      _availableUpdate != null && _availableUpdate!.version != _skippedVersion;

  bool get isChecking => _isChecking;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  /// Loads persisted state. Safe to call more than once.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final lastCheck = await _db.getSetting(_lastCheckKey);
      if (lastCheck != null) {
        final millis = int.tryParse(lastCheck);
        if (millis != null) {
          _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      _notifiedVersion = await _db.getSetting(_notifiedVersionKey);
      _skippedVersion = await _db.getSetting(_skippedVersionKey);
    } catch (_) {
      // A missing settings row must not stop the app from starting.
    }

    // On Android the native background check (UpdateCheckJobService) may have
    // already announced a release while the app was closed. Take over the newer
    // record so the same version is never announced twice.
    try {
      final nativeNotified = await _notifications.backgroundNotifiedVersion();
      if (nativeNotified != null) {
        final stored = _notifiedVersion;
        if (stored == null || VersionUtils.isNewer(nativeNotified, stored)) {
          _notifiedVersion = nativeNotified;
        }
      }
    } catch (_) {
      // Best effort: no bridge (or an older build) just means no shared state.
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// True when an automatic check is due (or [force] is set).
  bool shouldCheckNow({bool force = false}) {
    if (force) return true;
    final last = _lastCheckedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= checkInterval;
  }

  /// Checks GitHub for a newer release.
  ///
  /// Returns the [AppUpdate] when one is available, otherwise `null`.
  /// [notifyOnUpdate] posts a system notification the first time a version is
  /// discovered.
  Future<AppUpdate?> checkForUpdates({
    bool force = false,
    bool notifyOnUpdate = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isChecking) return _availableUpdate;
    if (!force && !shouldCheckNow()) return _availableUpdate;

    _isChecking = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClientOverride ?? http.Client();
      final response = await client
          .get(
            Uri.parse(AppConstants.githubReleasesApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Najikify-UpdateChecker',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (httpClientOverride == null) client.close();

      if (response.statusCode != 200) {
        _lastError = response.statusCode == 404
            ? 'No published releases found.'
            : 'Update server responded with HTTP ${response.statusCode}.';
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _lastError = 'Unexpected response from the update server.';
        return null;
      }

      final latest = AppUpdate.fromGitHubRelease(decoded);
      if (latest == null) {
        _lastError = 'Could not read the latest release information.';
        return null;
      }

      if (VersionUtils.isNewer(latest.version, AppConstants.appVersion)) {
        _availableUpdate = latest;
        // Only notify once per version, and not at all if the user already
        // chose "later" for this exact version.
        final alreadySkipped = _skippedVersion == latest.version;
        if (!alreadySkipped && notifyOnUpdate && _notifiedVersion != latest.version) {
          await _notifyAbout(latest);
        }
      } else {
        _availableUpdate = null;
      }

      _lastCheckedAt = DateTime.now();
      await _persistLastCheck();
      return _availableUpdate;
    } on TimeoutException {
      _lastError = 'Update check timed out. Check your internet connection.';
      return null;
    } catch (e) {
      _lastError = 'Could not check for updates: $e';
      return null;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _notifyAbout(AppUpdate update) async {
    final sent = await _notifications.showUpdateNotification(
      title: 'Najikify ${VersionUtils.withPrefix(update.version)} is available',
      body: 'You are on ${VersionUtils.withPrefix(AppConstants.appVersion)}. '
          'Tap to download the new version.',
      url: update.downloadUrl,
    );
    if (sent) {
      _notifiedVersion = update.version;
      try {
        await _db.setSetting(_notifiedVersionKey, update.version);
      } catch (_) {}
      // Keep the Android background check quiet for this version too.
      await _notifications.markUpdateNotified(update.version);
    }
  }

  Future<void> _persistLastCheck() async {
    final stamp = _lastCheckedAt;
    if (stamp == null) return;
    try {
      await _db.setSetting(
        _lastCheckKey,
        stamp.millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}
  }

  /// Hides the update prompt for this session and remembers the skipped version
  /// so it is not offered again. Settings still lists it.
  Future<void> skipUpdate() async {
    final update = _availableUpdate;
    if (update == null) return;
    _skippedVersion = update.version;
    try {
      await _db.setSetting(_skippedVersionKey, update.version);
    } catch (_) {}
    notifyListeners();
  }

  /// Opens the download for the artifact matching the current platform.
  Future<bool> openDownload() async {
    final update = _availableUpdate;
    if (update == null) return false;
    return _notifications.openExternal(update.downloadUrl);
  }

  /// Opens the GitHub release page (changelog and every asset).
  Future<bool> openReleaseNotes() async {
    final update = _availableUpdate;
    if (update == null) return false;
    return _notifications.openExternal(update.releaseUrl);
  }

  @visibleForTesting
  void resetForTesting() {
    _availableUpdate = null;
    _isChecking = false;
    _isInitialized = false;
    _lastError = null;
    _lastCheckedAt = null;
    _notifiedVersion = null;
    _skippedVersion = null;
  }
}
