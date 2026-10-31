import 'package:flutter/material.dart';
import 'main_tab_screen.dart';
import 'signup_screen.dart';
import 'find_id_screen.dart';
import 'reset_password_screen.dart';
import 'worker_main_tab_screen.dart';
import 'qr_scan_test_screen.dart';
import 'detection_test_screen.dart';
import 'gate_detection_screen.dart'; // 테스트 버튼(게이트 실시간 테스트)용
import 'api_service.dart';
import 'fcm_service.dart';

// ★ 테스트 버튼 3개 표시 여부 (카메라/QR 테스트, PPE 감지 테스트, 게이트 실시간 테스트)
// 시연·제출 = false / 서버 없이 테스트할 때 = true
const bool showTestButtons = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idController = TextEditingController();
  final pwController = TextEditingController();
  bool loading = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 서버 로그인
  Future<void> _login() async {
    if (idController.text.trim().isEmpty || pwController.text.isEmpty) {
      _snack('아이디와 비밀번호를 입력해주세요');
      return;
    }

    setState(() => loading = true);
    try {
      final result = await ApiService.login(
        idController.text.trim(),
        pwController.text,
      );
      if (result['success'] == true) {
        // 토큰 저장
        await ApiService.saveToken(
          result['token'] ?? '',
          result['userId'] ?? '',
          result['role'] ?? '',
        );

        // ── FCM 토큰을 서버에 저장 (로그인 성공 후) ──
        // 실패해도 로그인 흐름은 막지 않음
        FcmService.registerTokenToServer();

        // ── 로그인 전에 알림을 눌렀었으면 → 홈 대신 알림 탭으로 ──
        final openNotifications = FcmService.consumePendingOpen();

        if (!mounted) return;
        // role에 따라 자동 이동
        final role = result['role'];
        if (role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainTabScreen(
                initialIndex: openNotifications
                    ? MainTabScreen.notificationTabIndex
                    : 0,
              ),
            ),
          );
        } else if (role == 'WORKER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerMainTabScreen(
                initialIndex: openNotifications
                    ? WorkerMainTabScreen.notificationTabIndex
                    : 0,
              ),
            ),
          );
        } else {
          _snack('알 수 없는 역할: $role');
        }
      } else {
        _snack('로그인 실패: 아이디 또는 비밀번호를 확인해주세요');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 70),
                const Text(
                  'AI 스마트 안전 메이트',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 70),

                const Text(
                  '로그인',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '아이디와 비밀번호를 입력하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: idController,
                  decoration: _inputStyle('아이디'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwController,
                  obscureText: true,
                  decoration: _inputStyle('비밀번호'),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: loading ? null : _login,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loading ? '로그인 중...' : '로그인',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                _linkButton('아이디 찾기', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindIdScreen()),
                  );
                }),
                const SizedBox(height: 16),
                _linkButton('비밀번호 재설정', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _linkButton('회원가입', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                }),

                // ── 테스트 버튼 3개 (showTestButtons = true일 때만 보임) ──
                if (showTestButtons) ...[
                  // 카메라/QR 테스트
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScanTestScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6FA8F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '카메라/QR 테스트',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // PPE 감지 테스트 (사진 1장 방식, 초기 모델 확인용)
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DetectionTestScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PPE 감지 테스트',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // 게이트 실시간 테스트 (서버 없이 QR 인증 건너뛰고 감지 화면 바로 열기)
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GateDetectionScreen(
                            verifiedUserId: 'test',
                            verifiedName: '테스트',
                            verifiedSiteId: 0,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D9E75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '게이트 실시간 테스트',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.3),
      ),
    );
  }
}
