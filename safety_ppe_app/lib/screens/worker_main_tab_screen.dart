import 'package:flutter/material.dart';
import 'worker_home_screen.dart';
import 'worker_qr_screen.dart';
import 'worker_settings_screen.dart';
import 'worker_notification_screen.dart';
import 'worker_status_screen.dart';

class WorkerMainTabScreen extends StatefulWidget {
  // 처음 열 탭 번호 (0 홈, 1 QR, 2 현황, 3 알림, 4 설정). 기본값 0 = 홈
  // 알림을 눌러서 들어올 때는 3(알림)으로 열림
  final int initialIndex;

  const WorkerMainTabScreen({super.key, this.initialIndex = 0});

  // 알림 탭 번호 (fcm_service에서 사용)
  static const int notificationTabIndex = 3;

  @override
  State<WorkerMainTabScreen> createState() => _WorkerMainTabScreenState();
}

class _WorkerMainTabScreenState extends State<WorkerMainTabScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const WorkerHomeScreen(), // 홈
    const WorkerQrScreen(isTab: true), // QR (탭이라 뒤로가기 없음)
    const WorkerStatusScreen(isTab: true), // 현황
    const WorkerNotificationScreen(isTab: true), // 알림
    const WorkerSettingsScreen(), // 설정
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
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A1A1A),
        unselectedItemColor: const Color(0xFFB0B0B0),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '현황'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

class _WPlaceholder extends StatelessWidget {
  final String name;
  const _WPlaceholder(this.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$name 화면 준비 중',
          style: const TextStyle(fontSize: 16, color: Color(0xFF9A9A9A)),
        ),
      ),
    );
  }
}
