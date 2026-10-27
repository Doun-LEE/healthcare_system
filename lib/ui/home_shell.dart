import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'calendar_screen.dart';
import 'gym_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 2; // 홈이 가운데
  Timer? _inboxTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 파트너 요청/루틴 제안은 앱을 열 때, 돌아올 때, 그리고 2분마다 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _inboxTimer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final state = context.read<AppState>();
    state.resumeSync().whenComplete(() {
      state.catchUpMissed();
      state.refreshInbox();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    if (i == 0 || i == 2) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const CalendarScreen(),
      HomeScreen(onGoToTab: _go),
      const StatsScreen(),
      const GymScreen(),
      const ProfileScreen(),
    ];
    // 홈 배지: 파트너 요청·루틴 제안 + 안 읽은 채팅
    final inboxCount = context.select<AppState, int>((s) => s.inbox.length + s.unreadTotal);
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _go,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '오늘'),
          const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '달력'),
          NavigationDestination(
            icon: Badge(isLabelVisible: inboxCount > 0, label: Text('$inboxCount'), child: const Icon(Icons.home_outlined)),
            selectedIcon: Badge(isLabelVisible: inboxCount > 0, label: Text('$inboxCount'), child: const Icon(Icons.home)),
            label: '홈',
          ),
          const NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '기록'),
          const NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: '헬스장'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}
