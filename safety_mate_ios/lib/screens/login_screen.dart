import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'signup_screen.dart';
import 'find_id_screen.dart';
import 'reset_password_screen.dart';
import 'manager_main_screen.dart';
import 'worker_main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 입력값을 읽기 위한 컨트롤러
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  // 로그인 실행
  Future<void> _login() async {
    final userId = _idController.text.trim();
    final password = _pwController.text.trim();

    // 빈칸 확인
    if (userId.isEmpty || password.isEmpty) {
      _showMessage('아이디와 비밀번호를 입력하세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 서버에 로그인 요청
      final result = await ApiService.login(userId: userId, password: password);
      print('=== 로그인 응답: $result');

      // 토큰 저장
      final token = result['token'] as String;
      await TokenStorage.saveToken(token);

      // 유저 아이디 저장 (Inspection inspectorUserId 등에 사용)
      final loginUserId = result['userId'] as String?;
      print('=== userId: $loginUserId');
      if (loginUserId != null) {
        await TokenStorage.saveUserId(loginUserId);
      }

      // FCM 토큰 받아서 서버 전송 (푸시 알림용)
      try {
        // iOS 알림 권한 요청
        await FirebaseMessaging.instance.requestPermission();
        // FCM 토큰 받기
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('=== FCM 토큰: $fcmToken');
        if (fcmToken != null) {
          await ApiService.sendFcmToken(fcmToken: fcmToken);
          print('=== FCM 토큰 서버 전송 성공');
        }
      } catch (e) {
        print('=== FCM 토큰 전송 실패(무시): $e');
        // FCM 실패해도 로그인은 계속 진행
      }

      // 역할에 따라 분기
      final role = result['role'] as String;

      if (!mounted) return;

      if (role == 'ADMIN') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ManagerMainScreen()),
          (route) => false,
        );
      } else {
        // WORKER
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WorkerMainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('=== 로그인 에러: $e');
      if (!mounted) return;
      _showMessage('아이디 또는 비밀번호가 올바르지 않습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AI 스마트 안전 메이트',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '로그인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '아이디와 비밀번호를 입력하세요',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _idController,
                decoration: const InputDecoration(hintText: '아이디'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호'),
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('로그인'),
              ),
              const SizedBox(height: 20),

              // 하단 링크들
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text('회원가입'),
                  ),
                  const Text(
                    '·',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FindIdScreen()),
                      );
                    },
                    child: const Text('아이디 찾기'),
                  ),
                  const Text(
                    '·',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResetPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text('비밀번호 재설정'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
