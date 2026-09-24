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
      var allowed = _notificationsAllowed;
      if (allowed == null) {
        final status = await Permission.notification.request();
        allowed = status.isGranted || status.isLimited;
        _notificationsAllowed = allowed;
      }
      if (!allowed) return false;

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
