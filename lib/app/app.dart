import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../features/transfers/incoming_transfer_dialog.dart';
import '../features/updates/star_prompt_dialog.dart';
import '../features/updates/update_available_dialog.dart';
import '../models/app_update.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupPrompts());
  }

  Future<void> _runStartupPrompts() async {
    final update = await _checkForUpdatesOnStart();
    if (!mounted) return;
    await _maybeShowStarPrompt(hasPendingUpdate: update != null);
  }

  /// Runs the throttled update check after the first frame and offers the new
  /// release in-app. The service also posts a system notification (Android /
  /// Linux), at most once per discovered version. Returns the update so the
  /// star prompt can yield to it.
  Future<AppUpdate?> _checkForUpdatesOnStart() async {
    final updateService = UpdateService();
    try {
      final update = await updateService.checkForUpdates();
      if (!mounted || update == null) return update;

      final navigatorContext = rootNavigatorKey.currentState?.context;
      if (navigatorContext == null || !navigatorContext.mounted) {
        return update;
      }
      await UpdateAvailableDialog.showIfAvailable(navigatorContext, update);
      return update;
    } catch (_) {
      // An update check must never interfere with app startup.
      return null;
    }
  }

  /// Shows the occasional \"Do you like Najikify?\" prompt: random, at most
  /// once per 14 days, never before the 5th launch, auto-dismissed after 5
  /// seconds, and never competing with an update dialog.
  Future<void> _maybeShowStarPrompt({required bool hasPendingUpdate}) async {
    final starService = StarPromptService();
    try {
      await starService.recordLaunch();
      final show = await starService.shouldShow(
        hasPendingUpdate: hasPendingUpdate,
      );
      if (!show || !mounted) return;

      final starContext = rootNavigatorKey.currentState?.context;
      if (starContext == null || !starContext.mounted) return;
      await starService.recordShown();
      if (!mounted || !starContext.mounted) return;
      await showDialog<void>(
        context: starContext,
        barrierDismissible: true,
        builder: (_) => const StarPromptDialog(),
      );
    } catch (_) {
      // A star prompt must never interfere with app startup.
    }
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
