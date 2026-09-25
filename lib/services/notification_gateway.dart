import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cross-platform gateway for the things the update flow needs to reach the
/// operating system: posting a system notification and opening a link in the
/// user's browser.
///
/// * **Android** — notifications are posted through the `najikify/platform`
///   method channel implemented in `MainActivity.kt` (a `NotificationCompat`
///   notification on a dedicated "Updates" channel). The `POST_NOTIFICATIONS`
///   runtime permission is requested before the first notification and a denied
///   permission degrades to "no system notification" instead of an error.
/// * **Linux** — notifications are delegated to `notify-send` (libnotify), which
///   is present on GNOME/KDE and degrades silently when it is missing.
///
/// Every method is best-effort: none of them throw, because a missing
/// notification must never break the app.
class NotificationGateway {
  static final NotificationGateway _instance = NotificationGateway._internal();
  factory NotificationGateway() => _instance;
  NotificationGateway._internal();

  static const MethodChannel _channel = MethodChannel('najikify/platform');

  /// Cached so we only ask Android once per process.
  bool? _notificationsAllowed;

  /// True when the platform is able to post system notifications at all.
  bool get isSupported => Platform.isAndroid || Platform.isLinux;

  /// Asks for the notification permission up front (Android 13+).
  ///
  /// Called once at startup so that the *background* update check
  /// (`UpdateCheckJobService`, armed via [scheduleBackgroundUpdateChecks]) is
  /// able to post its notification later, when the app is not running. A denied
  /// permission simply means "no system notification"; everything else keeps
  /// working.
  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      var allowed = _notificationsAllowed;
      if (allowed == null) {
        final status = await Permission.notification.request();
        allowed = status.isGranted || status.isLimited;
        _notificationsAllowed = allowed;
      }
      return allowed;
    } catch (e) {
      debugPrint('NotificationGateway: permission request failed: $e');
      return false;
    }
  }

  /// Arms the periodic background release check (Android only).
  ///
  /// The check runs from a JobScheduler job, so a new Najikify release is
  /// announced in the notification centre without the user opening the app.
  /// No-op on Linux, where updates are checked while the app is running.
  Future<void> scheduleBackgroundUpdateChecks() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('scheduleUpdateCheck');
    } catch (e) {
      debugPrint('NotificationGateway: could not schedule update checks: $e');
    }
  }

  /// The version the background check already announced, or `null`.
  ///
  /// Shared with [UpdateService.initialize] so a release is announced at most
  /// once across the Dart and the native check.
  Future<String?> backgroundNotifiedVersion() async {
    if (!Platform.isAndroid) return null;
    try {
      final version = await _channel.invokeMethod<String>('getNotifiedVersion');
      return (version == null || version.isEmpty) ? null : version;
    } catch (e) {
      debugPrint('NotificationGateway: could not read notified version: $e');
      return null;
    }
  }

  /// Records that [version] has been announced by the Dart side.
  Future<void> markUpdateNotified(String version) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('markUpdateNotified', {
        'version': version,
      });
    } catch (e) {
      debugPrint('NotificationGateway: could not record notified version: $e');
    }
  }

  /// Posts an "update available" notification.
  ///
  /// [url] is opened when the user taps the notification on Android.
  Future<bool> showUpdateNotification({
    required String title,
    required String body,
    String? url,
  }) async {
    if (Platform.isAndroid) {
      return _showAndroidNotification(title: title, body: body, url: url);
    }
    if (Platform.isLinux) {
      return _showLinuxNotification(title: title, body: body);
    }
    return false;
  }

  Future<bool> _showAndroidNotification({
    required String title,
    required String body,
    String? url,
  }) async {
    try {
      // Android 13+ requires an explicit runtime grant for notifications.
      if (!await ensurePermission()) return false;

      final shown = await _channel.invokeMethod<bool>('showNotification', {
        'title': title,
        'body': body,
        if (url != null) 'url': url,
      });
      return shown ?? false;
    } catch (e) {
      debugPrint('NotificationGateway: Android notification failed: $e');
      return false;
    }
  }

  Future<bool> _showLinuxNotification({
    required String title,
    required String body,
  }) async {
    try {
      final result = await Process.run('notify-send', [
        '--app-name=Najikify',
        '--icon=najikify',
        '--urgency=normal',
        title,
        body,
      ]).timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      // notify-send is not installed on this desktop — not an error.
      return false;
    }
  }

  /// Opens [url] in the user's default browser.
  Future<bool> openExternal(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('NotificationGateway: could not open $url: $e');
      return false;
    }
  }
}
