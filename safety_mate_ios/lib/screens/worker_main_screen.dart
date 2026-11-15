import 'package:flutter/material.dart';
import '../theme.dart';
import 'worker_home_screen.dart';
import 'worker_qr_screen.dart';
import 'worker_status_screen.dart';
import 'worker_alert_screen.dart';
import 'worker_settings_screen.dart';

class WorkerMainScreen extends StatefulWidget {
  const WorkerMainScreen({super.key});

  @override
  State<WorkerMainScreen> createState() => _WorkerMainScreenState();
}

class _WorkerMainScreenState extends State<WorkerMainScreen> {
  int currentIndex = 0; // 선택된 탭
  int _qrReload = 0; // QR 탭 들어올 때마다 새로고침용

  @override
  Widget build(BuildContext context) {
    // 탭에 대응하는 5개 화면 (QR은 key가 바뀌면 새로 조회됨)
    final screens = [
      const WorkerHomeScreen(),
      WorkerQrScreen(key: ValueKey(_qrReload)),
      const WorkerStatusScreen(),
      const WorkerAlertScreen(),
      const WorkerSettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() {
          if (index == 1) _qrReload++; // QR 탭 누르면 새로 조회
          currentIndex = index;
        }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            label: '현황',
          ),
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
