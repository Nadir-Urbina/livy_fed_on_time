import 'dart:async';

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
  Timer? _clock;
  late bool _daytime = _isDaytime(DateTime.now());

  /// 6am–6pm reads as "Today"; the rest of the clock is "Tonight". Deliberately
  /// not the theme's day/dusk/night split — this is only about which word a
  /// parent expects to see on the tab at that hour.
  static bool _isDaytime(DateTime t) => t.hour >= 6 && t.hour < 18;

  @override
  void initState() {
    super.initState();
    // The label flips twice a day; a one-minute tick is plenty to catch it
    // without waiting for some other rebuild to happen along.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = _isDaytime(DateTime.now());
      if (next != _daytime) setState(() => _daytime = next);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

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
          NavigationDestination(
            icon: Icon(_daytime
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_round_outlined),
            selectedIcon:
                Icon(_daytime ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            label: _daytime ? 'Today' : 'Tonight',
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
