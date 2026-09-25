import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../features/transfers/incoming_transfer_dialog.dart';
import '../features/updates/star_prompt_dialog.dart';
import '../features/updates/update_available_dialog.dart';
import '../models/transfer.dart';
import '../services/discovery_service.dart';
import '../services/history_service.dart';
import '../services/network_service.dart';
import '../services/pairing_service.dart';
import '../services/settings_service.dart';
import '../services/star_prompt_service.dart';
import '../services/transfer_service.dart';
import '../services/update_service.dart';
import 'router.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class NajikifyApp extends StatefulWidget {
  const NajikifyApp({super.key});

  @override
  State<NajikifyApp> createState() => _NajikifyAppState();
}

class _NajikifyAppState extends State<NajikifyApp> {
  @override
  void initState() {
    super.initState();
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdatesOnStart());
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
    // Only prompt for completed transfers with success status
    if (completed.status != TransferStatus.completed) return;

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
            home: const MainNavigationScaffold(),
          );
        },
      ),
    );
  }
}
