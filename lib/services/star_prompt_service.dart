import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import 'database_service.dart';
import 'notification_gateway.dart';

/// Asks the user to star Najikify on GitHub right after a moment of delight —
/// a successfully finished file transfer (like the "Rate us" prompts in other
/// apps).
///
/// Rules (same on Linux and Android):
/// * Only after a transfer completes — never randomly on startup.
/// * Never for the first [minCompletedTransfers] transfers, so the prompt is
///   earned by a working app.
/// * At most once every [promptInterval], and only every [promptEveryNth]
///   completion after that, so it never nags.
/// * Never while an update is available — the update flow has priority.
/// * The dialog stays on screen until the user closes it — there is no
///   auto-dismiss timer, so the prompt can never disappear unnoticed.
/// * "Don't ask again" and a completed star are remembered forever (until app
///   data is cleared).
class StarPromptService extends ChangeNotifier {
  static final StarPromptService _instance = StarPromptService._internal();
  factory StarPromptService() => _instance;
  StarPromptService._internal();

  /// Minimum completed transfers before the prompt can ever appear.
  /// Set to 1 so user is prompted right after their very first successful transfer.
  static const int minCompletedTransfers = 1;

  /// Minimum gap between two prompts.
  static const Duration promptInterval = Duration(days: 14);

  /// After the first prompt, show at most every Nth completed transfer
  /// (combined with [promptInterval], whichever is stricter wins).
  static const int promptEveryNth = 5;

  static const String _completedCountKey = 'star_completed_count';
  static const String _promptCountKey = 'star_prompt_count';
  static const String _lastPromptKey = 'star_last_prompt_ms';
  static const String _dismissedForeverKey = 'star_dismissed_forever';
  static const String _starredKey = 'star_starred';

  final DatabaseService _db = DatabaseService();

  bool _isInitialized = false;

  /// True when every quiet condition holds for the just-finished transfer.
  ///
  /// Pass [hasPendingUpdate] as true while an update dialog/banner is showing
  /// so the two prompts never compete.
  Future<bool> shouldShowAfterTransfer({bool hasPendingUpdate = false}) async {
    if (hasPendingUpdate) return false;
    try {
      final dismissed =
          (await _db.getSetting(_dismissedForeverKey)) == '1';
      if (dismissed) return false;
      if ((await _db.getSetting(_starredKey)) == '1') return false;

      final completed =
          int.tryParse(await _db.getSetting(_completedCountKey) ?? '0') ?? 0;
      if (completed < minCompletedTransfers) return false;

      final prompts =
          int.tryParse(await _db.getSetting(_promptCountKey) ?? '0') ?? 0;
      if (prompts > 0 && completed % promptEveryNth != 0) return false;

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

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records one successfully completed transfer; returns the new count.
  /// This is the only trigger for the prompt — there is no startup/random path.
  Future<int> recordCompletedTransfer() async {
    try {
      final current =
          int.tryParse(await _db.getSetting(_completedCountKey) ?? '0') ?? 0;
      final next = current + 1;
      await _db.setSetting(_completedCountKey, next.toString());
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
      final prompts =
          int.tryParse(await _db.getSetting(_promptCountKey) ?? '0') ?? 0;
      await _db.setSetting(_promptCountKey, (prompts + 1).toString());
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
