import 'package:flutter/material.dart';
import 'worker_notification_settings_screen.dart';
import 'worker_mypage_screen.dart';

class WorkerSettingsScreen extends StatelessWidget {
  const WorkerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                '설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 알림 설정 → 25
              _SettingItem(
                icon: Icons.notifications_none,
                title: '알림 설정',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkerNotificationSettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // 마이페이지 → 27
              _SettingItem(
                icon: Icons.person_outline,
                title: '마이페이지',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkerMyPageScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF4A4A4A)),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC4C4C4)),
          ],
        ),
      ),
    );
  }
}
