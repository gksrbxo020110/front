import 'package:flutter/material.dart';
import 'worker_site_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'withdraw_screen.dart';
import 'api_service.dart';

class WorkerMyPageScreen extends StatefulWidget {
  const WorkerMyPageScreen({super.key});

  @override
  State<WorkerMyPageScreen> createState() => _WorkerMyPageScreenState();
}

class _WorkerMyPageScreenState extends State<WorkerMyPageScreen> {
  String name = '';
  String siteName = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
  }

  Future<void> _loadMyInfo() async {
    try {
      final result = await ApiService.getMyInfo();
      if (result['success'] == true) {
        setState(() {
          name = result['name'] ?? '';
          siteName = result['siteName'] ?? '';
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = siteName.isNotEmpty ? '$siteName · 건설노동자' : '건설노동자';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // 앱바
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
                  ),
                  const Text(
                    '마이페이지',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 프로필 카드 (건설노동자)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B6B6B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading ? '불러오는 중...' : (name.isEmpty ? '이름 없음' : name),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading ? '' : subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 현장 관리 → 노동자 현장 등록
              _MyItem(
                icon: Icons.apartment,
                title: '현장 관리',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkerSiteScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // 비밀번호 변경
              _MyItem(
                icon: Icons.lock_outline,
                title: '비밀번호 변경',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // 로그아웃 (토큰 삭제)
              _MyItem(icon: Icons.logout, title: '로그아웃', onTap: _logout),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // 회원 탈퇴 (노동자)
              _MyItem(
                icon: Icons.person_remove_alt_1_outlined,
                title: '회원 탈퇴',
                danger: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WithdrawScreen(isManager: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  const _MyItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = danger ? const Color(0xFFE24B4A) : const Color(0xFF1A1A1A);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: danger ? const Color(0xFFE24B4A) : const Color(0xFF4A4A4A),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
            if (!danger) ...[
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFC4C4C4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
