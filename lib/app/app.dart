import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../features/transfers/incoming_transfer_dialog.dart';
import '../services/discovery_service.dart';
import '../services/history_service.dart';
import '../services/network_service.dart';
import '../services/pairing_service.dart';
import '../services/settings_service.dart';
import '../services/transfer_service.dart';
import 'router.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class LocalDropApp extends StatefulWidget {
  const LocalDropApp({super.key});

  @override
  State<LocalDropApp> createState() => _LocalDropAppState();
}

class _LocalDropAppState extends State<LocalDropApp> {
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
