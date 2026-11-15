import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';

class WorkerWithdrawScreen extends StatefulWidget {
  const WorkerWithdrawScreen({super.key});

  @override
  State<WorkerWithdrawScreen> createState() => _WorkerWithdrawScreenState();
}

class _WorkerWithdrawScreenState extends State<WorkerWithdrawScreen> {
  bool agreed = false; // 탈퇴 동의 체크
  bool _isLoading = false;

  // 비밀번호 입력 컨트롤러
  final _pwController = TextEditingController();

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 회원 탈퇴 실행
  Future<void> _withdraw() async {
    final password = _pwController.text.trim();
    if (password.isEmpty) {
      _showMessage('비밀번호를 입력하세요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 서버에 탈퇴 요청 (토큰은 함수 안에서 헤더에 실림)
      await ApiService.deleteAccount(password: password);

      // 성공 시 토큰 삭제
      await TokenStorage.deleteToken();

      if (!mounted) return;
      _showMessage('회원 탈퇴가 완료되었습니다');

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showMessage('탈퇴에 실패했습니다. 비밀번호를 확인하세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '회원 탈퇴',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              const Text(
                '정말 탈퇴하시겠어요?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '탈퇴 시 계정과 모든 데이터가 삭제되며\n복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 삭제되는 정보 (빨강 박스)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '삭제되는 정보',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 계정 정보 (아이디, 이름, 닉네임)',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• 현장 소속 정보',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• QR 코드 및 미착용 이력',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '비밀번호 확인',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '현재 비밀번호를 입력하세요'),
              ),
              const SizedBox(height: 16),

              // 동의 체크
              Row(
                children: [
                  Checkbox(
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v ?? false),
                    activeColor: AppColors.danger,
                  ),
                  const Expanded(
                    child: Text(
                      '위 내용을 확인했으며 탈퇴에 동의합니다',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 회원 탈퇴 버튼 (동의해야 활성화)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: agreed ? AppColors.danger : null,
                ),
                onPressed: (agreed && !_isLoading) ? _withdraw : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('회원 탈퇴'),
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
