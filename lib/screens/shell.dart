import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/tokens.dart';
import 'badges/badges_screen.dart';
import 'care/care_hub_screen.dart';
import 'history/history_screen.dart';
import 'insights/insights_screen.dart';
import 'home/home_screen.dart';

/// Bottom-nav shell: Home (dial), History, Badges, Care hub.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recallCount = app.relevantRecalls.length;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          InsightsScreen(),
          BadgesScreen(),
          CareHubScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 68,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.nightlight_round_outlined),
            selectedIcon: Icon(Icons.nightlight_round),
            label: 'Tonight',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Badges',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: recallCount > 0,
              backgroundColor: LivyColors.rose,
              label: Text('$recallCount'),
              child: const Icon(Icons.spa_outlined),
            ),
            selectedIcon: const Icon(Icons.spa_rounded),
            label: 'Care',
          ),
        ],
      ),
    );
  }
}
