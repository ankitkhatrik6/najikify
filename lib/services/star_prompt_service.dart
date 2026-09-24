import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import 'database_service.dart';
import 'notification_gateway.dart';

/// Occasionally asks the user to star Najikify on GitHub.
///
/// Rules (same on Linux and Android):
/// * Never before the 5th app launch, so first-time users are left alone.
/// * At most once every 14 days, and only on a ~15% random roll, so the
///   prompt feels occasional rather than nagging.
/// * Never while an update is available — the update flow has priority.
/// * The dialog auto-dismisses after 5 seconds without any user action.
/// * \"Don't ask again\" is remembered forever (until app data is cleared).
class StarPromptService extends ChangeNotifier {
  static final StarPromptService _instance = StarPromptService._internal();
  factory StarPromptService() => _instance;
  StarPromptService._internal() : _random = math.Random();

  /// Minimum launches before the prompt can ever appear.
  static const int minLaunches = 5;

  /// Minimum gap between two prompts.
  static const Duration promptInterval = Duration(days: 14);

  /// Probability (0..1) of showing once the other gates pass.
  static const double showProbability = 0.15;

  /// The dialog dismisses itself after this long.
  static const Duration autoDismissAfter = Duration(seconds: 5);

  static const String _launchCountKey = 'star_launch_count';
  static const String _lastPromptKey = 'star_last_prompt_ms';
  static const String _dismissedForeverKey = 'star_dismissed_forever';
  static const String _starredKey = 'star_starred';

  final DatabaseService _db = DatabaseService();
  final math.Random _random;

  bool _isInitialized = false;

  @visibleForTesting
  StarPromptService.forTesting({math.Random? random})
      : _random = random ?? math.Random();

  /// True when every quiet condition holds and the random roll passes.
  ///
  /// Pass [hasPendingUpdate] as true while an update dialog/banner is showing
  /// so the two prompts never compete.
  Future<bool> shouldShow({bool hasPendingUpdate = false}) async {
    if (hasPendingUpdate) return false;
    try {
      final dismissed =
          (await _db.getSetting(_dismissedForeverKey)) == '1';
      if (dismissed) return false;
      if ((await _db.getSetting(_starredKey)) == '1') return false;

      final launches =
          int.tryParse(await _db.getSetting(_launchCountKey) ?? '0') ?? 0;
      if (launches < minLaunches) return false;

      final lastRaw = await _db.getSetting(_lastPromptKey);
      if (lastRaw != null) {
        final last = int.tryParse(lastRaw);
        if (last != null) {
          final elapsed = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(last),
          );
          if (elapsed < promptInterval) return false;
        }
      }

      return _random.nextDouble() < showProbability;
    } catch (_) {
      return false;
    }
  }

  /// Records one app launch; returns the new launch count.
  Future<int> recordLaunch() async {
    try {
      final current =
          int.tryParse(await _db.getSetting(_launchCountKey) ?? '0') ?? 0;
      final next = current + 1;
      await _db.setSetting(_launchCountKey, next.toString());
      return next;
    } catch (_) {
      return 0;
    }
  }

  /// Remembers that the prompt was shown now (starts the 14-day quiet period).
  Future<void> recordShown() async {
    try {
      await _db.setSetting(
        _lastPromptKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}
    notifyListeners();
  }

  /// User tapped \"Star on GitHub\": open the repo and stop asking.
  Future<bool> starNow() async {
    try {
      await _db.setSetting(_starredKey, '1');
    } catch (_) {}
    notifyListeners();
    return NotificationGateway().openExternal(AppConstants.githubStarUrl);
  }

  /// User chose \"Don't ask again\".
  Future<void> dismissForever() async {
    try {
      await _db.setSetting(_dismissedForeverKey, '1');
    } catch (_) {}
    notifyListeners();
  }

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _isInitialized = true;
  }
}
