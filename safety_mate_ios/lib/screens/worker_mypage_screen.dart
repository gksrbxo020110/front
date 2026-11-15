import 'package:flutter/material.dart';
import '../theme.dart';
import 'change_password_screen.dart';
import 'worker_site_screen.dart';
import 'worker_withdraw_screen.dart';
import 'login_screen.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';

class WorkerMypageScreen extends StatefulWidget {
  const WorkerMypageScreen({super.key});

  @override
  State<WorkerMypageScreen> createState() => _WorkerMypageScreenState();
}

class _WorkerMypageScreenState extends State<WorkerMypageScreen> {
  Map<String, dynamic>? myInfo; // 내 정보 (name, role, siteId, siteName)
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
  }

  // 내 정보 조회
  Future<void> _loadMyInfo() async {
    setState(() => isLoading = true);
    try {
      final info = await ApiService.getMyInfo();
      if (!mounted) return;
      setState(() => myInfo = info);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내 정보 조회 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = myInfo?['name'] ?? '';
    final siteName = myInfo?['siteName'];
    // 소속 현장 있으면 "현장명 · 건설노동자", 없으면 "소속 현장 없음 · 건설노동자"
    final subtitle = (siteName != null && siteName.toString().isNotEmpty)
        ? '$siteName · 건설노동자'
        : '소속 현장 없음 · 건설노동자';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 프로필
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 메뉴들
            _menuItem(
              icon: Icons.location_on_outlined,
              title: '현장 관리',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkerSiteScreen()),
                );
              },
            ),
            const Divider(height: 1),
            _menuItem(
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
            const Divider(height: 1),
            _menuItem(
              icon: Icons.logout,
              title: '로그아웃',
              onTap: () => _showLogoutDialog(context),
            ),
            const Divider(height: 1),
            _menuItem(
              icon: Icons.person_off_outlined,
              title: '회원 탈퇴',
              titleColor: AppColors.danger,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkerWithdrawScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.textPrimary),
      title: Text(title, style: TextStyle(fontSize: 15, color: titleColor)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  // 로그아웃 확인 팝업
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              '로그아웃 하시겠어요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await TokenStorage.deleteToken(); // 토큰 삭제
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('로그아웃'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
