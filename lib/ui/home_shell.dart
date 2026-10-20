import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'gym_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const CalendarScreen(),
      const GymScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '오늘'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '달력'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: '헬스장'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}
