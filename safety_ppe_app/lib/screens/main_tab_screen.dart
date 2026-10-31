import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'notification_list_screen.dart';
import 'settings_screen.dart';

class MainTabScreen extends StatefulWidget {
  // 처음 열 탭 번호 (0 홈, 1 대시보드, 2 알림, 3 설정). 기본값 0 = 홈
  // 알림을 눌러서 들어올 때는 2(알림)로 열림
  final int initialIndex;

  const MainTabScreen({super.key, this.initialIndex = 0});

  // 알림 탭 번호 (fcm_service에서 사용)
  static const int notificationTabIndex = 2;

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    ManagerHomeScreen(), // 홈
    DashboardScreen(), // 대시보드
    NotificationListScreen(), // 알림
    SettingsScreen(), // 설정
  ];

  @override
  void initState() {
    super.initState();
    // 잘못된 번호가 들어와도 앱이 안 죽게 범위 안으로 맞춤
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A1A1A),
        unselectedItemColor: const Color(0xFFB0B0B0),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '대시보드'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
