import 'package:flutter/material.dart';
import 'api_service.dart';

// 관리자 알림 설정
// 서버는 알림 ON/OFF 하나만 지원 (알림 종류 = 미착용 경고뿐)
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool enabled = true; // 미착용 경고 알림 (서버 연동)
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 현재 설정 불러오기
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final v = await ApiService.getNotificationSetting();
    if (!mounted) return;
    setState(() {
      enabled = v;
      loading = false;
    });
  }

  // 토글 → 서버 저장
  Future<void> _toggle(bool v) async {
    setState(() => enabled = v); // 화면 먼저 반영
    final ok = await ApiService.updateNotificationSetting(v);
    if (!ok && mounted) {
      // 실패하면 되돌리기
      setState(() => enabled = !v);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 설정 변경에 실패했습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // 앱바 (뒤로가기 + 가운데 제목)
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.chevron_left, size: 26),
                    ),
                  ),
                  const Text(
                    '알림 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
                  ),
                )
              else ...[
                _ToggleItem(
                  title: '미착용 경고 알림',
                  subtitle: '현장 노동자의 보호구 미착용이 감지되면 알림을 받아요',
                  value: enabled,
                  onChanged: _toggle,
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF7F77DD),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD3D1DB),
          ),
        ],
      ),
    );
  }
}
