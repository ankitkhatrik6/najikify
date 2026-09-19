import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transfers/transfers_screen.dart';
import '../services/transfer_service.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    final transferService = context.watch<TransferService>();
    final activeCount = transferService.activeTransfers.length;

    final screens = [
      HomeScreen(onNavigateTab: _onTabSelected),
      const TransfersScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    if (isDesktop) {
      // Desktop Layout with Sidebar Navigation Rail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.near_me_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount'),
                    child: const Icon(Icons.swap_horiz_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount'),
                    child: const Icon(Icons.swap_horiz_rounded),
                  ),
                  label: const Text('Transfers'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: Text('History'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Android & Mobile Layout with Bottom Navigation Bar
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
            label: 'Transfers',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
