import 'package:flutter/material.dart';
import '../theme.dart';
import 'manager_home_screen.dart';
import 'dashboard_screen.dart';
import 'notification_screen.dart';
import 'manager_settings_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    ManagerHomeScreen(),
    DashboardScreen(),
    NotificationScreen(),
    ManagerSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '대시보드'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: '알림',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
