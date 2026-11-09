import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../services/partner.dart';
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
  bool _askingSwap = false;

  /// 함께 하는 사람이 운동 바꾸기를 제안하면 어느 화면에 있든 바로 묻는다.
  Future<void> _askSwap() async {
    if (_askingSwap || !mounted) return;
    final state = context.read<AppState>();
    if (state.swapProposals.isEmpty) return;
    _askingSwap = true;
    final InboxItem item = state.swapProposals.first;
    final a = exerciseById(item.fromEx ?? '')?.name ?? '운동';
    final b = exerciseById(item.toEx ?? '')?.name ?? '새 운동';
    final d = item.date;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.swap_horiz),
        title: Text('${item.fromName} 님의 운동 바꾸기 제안'),
        content: Text('${d == null ? '' : '${d.month}/${d.day} '}같이 하는 루틴에서\n‘$a’ → ‘$b’(으)로 바꾸자고 해요.\n\n거절하면 나는 $a 그대로 해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('거절 (나는 그대로)')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('수락')),
        ],
      ),
    );
    if (accept != null) {
      final msg = await state.answerSwap(item, accept: accept);
      if (mounted && msg.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    _askingSwap = false;
    if (mounted && state.swapProposals.isNotEmpty) _askSwap();
  }

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
    final swaps = context.select<AppState, int>((s) => s.swapProposals.length);
    if (swaps > 0 && !_askingSwap) WidgetsBinding.instance.addPostFrameCallback((_) => _askSwap());
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
