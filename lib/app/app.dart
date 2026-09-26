import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../features/splash/splash_screen.dart';
import '../features/transfers/incoming_transfer_dialog.dart';
import '../features/updates/star_prompt_dialog.dart';
import '../features/updates/update_available_dialog.dart';
import '../models/transfer.dart';
import '../services/discovery_service.dart';
import '../services/history_service.dart';
import '../services/network_service.dart';
import '../services/notification_gateway.dart';
import '../services/pairing_service.dart';
import '../services/settings_service.dart';
import '../services/star_prompt_service.dart';
import '../services/transfer_service.dart';
import '../services/update_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class NajikifyApp extends StatefulWidget {
  const NajikifyApp({super.key});

  @override
  State<NajikifyApp> createState() => _NajikifyAppState();
}

class _NajikifyAppState extends State<NajikifyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Configure transfer service prompt hook
    final transferService = TransferService();
    transferService.onIncomingTransfer = (sender, files, totalBytes, savePath) async {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return true;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => IncomingTransferDialog(
          sender: sender,
          files: files,
          totalBytes: totalBytes,
          savePath: savePath,
        ),
      );

      return result ?? false;
    };

    // "Rate us"-style prompt: after each successful transfer offer the GitHub
    // star dialog (gated inside StarPromptService, never random on startup).
    transferService.onTransferCompleted = _maybeShowStarPromptAfterTransfer;

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Safety net for desktop (and for phones that never reboot the job):
    // re-run the throttled check whenever the app comes back to the foreground,
    // so a release published while Najikify was open still notifies and offers
    // the update. The 6-hour throttle makes this a no-op most of the time.
    _checkForUpdatesOnStart();
  }

  /// One-time update bootstrap: ask for the notification permission, arm the
  /// Android background check, then run the throttled in-app check.
  ///
  /// The permission is requested here (and not only when a notification is
  /// about to be posted) so the background job can notify the user later, when
  /// the app is closed — the same behaviour as other apps' update alerts.
  Future<void> _bootstrapUpdates() async {
    final notifications = NotificationGateway();
    try {
      await notifications.ensurePermission();
      await notifications.scheduleBackgroundUpdateChecks();
    } catch (_) {
      // Notifications are optional; the update flow still works in-app.
    }
    if (!mounted) return;
    await _checkForUpdatesOnStart();
  }

  /// Runs the throttled update check after the first frame and offers the new
  /// release in-app. The service also posts a system notification (Android /
  /// Linux), at most once per discovered version.
  Future<void> _checkForUpdatesOnStart() async {
    final updateService = UpdateService();
    try {
      final update = await updateService.checkForUpdates();
      if (!mounted || update == null) return;

      final navigatorContext = rootNavigatorKey.currentState?.context;
      if (navigatorContext == null || !navigatorContext.mounted) {
        return;
      }
      await UpdateAvailableDialog.showIfAvailable(navigatorContext, update);
      return;
    } catch (_) {
      // An update check must never interfere with app startup.
      return;
    }
  }

  /// "Rate us"-style flow: called by [TransferService] once per successful
  /// transfer. Counts the completion, then shows the star dialog only when
  /// the service gates pass (min transfers, spacing, no pending update).
  /// Never blocks or fails the transfer UI — everything is best-effort.
  void _maybeShowStarPromptAfterTransfer(Transfer completed) {
    // Only prompt for transfers that really finished successfully.
    if (completed.state != TransferState.completed) return;

    final starService = StarPromptService();
    starService.recordCompletedTransfer().then((_) async {
      if (!mounted) return;
      final hasPendingUpdate = UpdateService().availableUpdate != null;
      final show = await starService.shouldShowAfterTransfer(
        hasPendingUpdate: hasPendingUpdate,
      );
      if (!show || !mounted) return;

      // Ensure any pending route changes settle before checking root navigator
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final starContext = rootNavigatorKey.currentState?.context;
      if (starContext == null || !starContext.mounted) return;
      await starService.recordShown();
      if (!mounted || !starContext.mounted) return;
      await showDialog<void>(
        context: starContext,
        barrierDismissible: true,
        builder: (_) => const StarPromptDialog(),
      );
    }).catchError((_) {
      // A star prompt must never interfere with transfers.
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SettingsService()),
        ChangeNotifierProvider.value(value: NetworkService()),
        ChangeNotifierProvider.value(value: DiscoveryService()),
        ChangeNotifierProvider.value(value: TransferService()),
        ChangeNotifierProvider.value(value: HistoryService()),
        ChangeNotifierProvider.value(value: PairingService()),
        ChangeNotifierProvider.value(value: UpdateService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.settings.themeMode,
            // Brand moment + first-frame cover: the app shell is pushed by the
            // splash once its ripple animation has played.
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
