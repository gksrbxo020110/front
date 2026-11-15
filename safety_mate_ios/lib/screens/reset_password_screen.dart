import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPwController = TextEditingController();
  final _newPwConfirmController = TextEditingController();

  bool _codeSent = false;
  bool emailVerified = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _newPwController.dispose();
    _newPwConfirmController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 이메일 인증 코드 발송 (purpose: RESET_PW)
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('이메일을 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.sendEmailCode(email: email, purpose: 'RESET_PW');
      setState(() => _codeSent = true);
      _showMessage('인증 코드가 발송되었습니다');
    } catch (e) {
      _showMessage('이메일 발송에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 이메일 인증 코드 검증 (purpose: RESET_PW)
  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('인증 코드를 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.verifyEmailCode(
        email: email,
        code: code,
        purpose: 'RESET_PW',
      );
      setState(() => emailVerified = true);
      _showMessage('이메일 인증이 완료되었습니다');
    } catch (e) {
      _showMessage('인증 코드가 올바르지 않습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 비밀번호 재설정
  Future<void> _resetPassword() async {
    final userId = _idController.text.trim();
    final email = _emailController.text.trim();
    final newPw = _newPwController.text.trim();
    final newPwConfirm = _newPwConfirmController.text.trim();

    if (userId.isEmpty || email.isEmpty || newPw.isEmpty) {
      _showMessage('모든 항목을 입력하세요');
      return;
    }
    if (!emailVerified) {
      _showMessage('이메일 인증을 완료하세요');
      return;
    }
    if (newPw != newPwConfirm) {
      _showMessage('새 비밀번호가 일치하지 않습니다');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.resetPassword(
        userId: userId,
        email: email,
        newPassword: newPw,
      );
      if (!mounted) return;
      _showMessage('비밀번호가 재설정되었습니다', color: AppColors.safe);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage('비밀번호 재설정에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Text(
                'AI 스마트 안전 메이트',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '비밀번호 재설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '본인 확인 후 새 비밀번호를 설정하세요',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // 아이디
              TextField(
                controller: _idController,
                decoration: const InputDecoration(hintText: '아이디 입력'),
              ),
              const SizedBox(height: 12),

              // 이메일 + 인증요청
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      enabled: !emailVerified,
                      decoration: const InputDecoration(hintText: '이메일 입력'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: (_isLoading || emailVerified) ? null : _sendCode,
                    child: const Text('인증 요청'),
                  ),
                ],
              ),

              // 코드 입력 (발송 후 나타남, 인증 완료 전까지)
              if (_codeSent && !emailVerified) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '인증 코드 6자리',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ],

              // 인증 완료 안내
              if (emailVerified) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '✓ 이메일 인증이 완료되었습니다',
                    style: TextStyle(fontSize: 12, color: AppColors.safe),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // 새 비밀번호
              TextField(
                controller: _newPwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPwConfirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호 확인'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('재설정 완료'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
