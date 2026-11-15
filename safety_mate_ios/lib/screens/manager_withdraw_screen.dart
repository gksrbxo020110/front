import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';

class ManagerWithdrawScreen extends StatefulWidget {
  const ManagerWithdrawScreen({super.key});

  @override
  State<ManagerWithdrawScreen> createState() => _ManagerWithdrawScreenState();
}

class _ManagerWithdrawScreenState extends State<ManagerWithdrawScreen> {
  bool agreed = false;
  bool _isLoading = false;
  bool _countLoading = true; // 노동자 수 조회 중

  // 비밀번호 입력 컨트롤러
  final _pwController = TextEditingController();

  // 소속 노동자 수 (서버에서 조회). 0명이어야 탈퇴 가능
  int workerCount = 0;

  bool get canWithdraw => workerCount == 0;

  @override
  void initState() {
    super.initState();
    _loadWorkerCount();
  }

  // 소속 노동자 수 조회
  Future<void> _loadWorkerCount() async {
    try {
      final count = await ApiService.getWorkerCount();
      if (!mounted) return;
      setState(() {
        workerCount = count;
        _countLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _countLoading = false);
    }
  }

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

              // 소속 노동자 있으면 탈퇴 불가 경고
              if (!canWithdraw) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: AppColors.danger,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '탈퇴할 수 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '소속 노동자 $workerCount명이 남아 있습니다.\n노동자를 모두 삭제한 후 탈퇴할 수 있습니다.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 삭제되는 정보
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
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
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 계정 정보 (아이디, 이름)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• 관리하던 현장 정보',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• 알림 및 설정 정보',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 비밀번호 확인
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

              // 탈퇴 버튼 (노동자 0명 + 동의 시에만 활성)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (canWithdraw && agreed)
                      ? AppColors.danger
                      : null,
                ),
                onPressed: (canWithdraw && agreed && !_isLoading)
                    ? _withdraw
                    : null,
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
            ],
          ),
        ),
      ),
    );
  }
}
