import 'package:flutter/material.dart';
import 'api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final userIdController = TextEditingController(); // 서버가 아이디 + 이메일 둘 다 확인
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final pwController = TextEditingController();
  final pwConfirmController = TextEditingController();

  bool codeSent = false; // 인증코드 발송됨
  bool emailVerified = false; // 이메일 인증 완료
  bool loading = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 인증코드 발송
  Future<void> _sendCode() async {
    if (userIdController.text.trim().isEmpty) {
      _snack('아이디를 입력해주세요');
      return;
    }
    if (emailController.text.trim().isEmpty) {
      _snack('이메일을 입력해주세요');
      return;
    }
    setState(() => loading = true);
    try {
      final ok = await ApiService.sendEmailCode(
        emailController.text.trim(),
        'RESET_PW',
      );
      if (ok) {
        if (mounted) setState(() => codeSent = true);
        _snack('인증코드가 이메일로 발송되었습니다');
      } else {
        _snack('인증코드 발송 실패. 가입된 이메일인지 확인해주세요');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 인증코드 확인
  Future<void> _verifyCode() async {
    if (codeController.text.trim().isEmpty) {
      _snack('인증코드를 입력해주세요');
      return;
    }
    setState(() => loading = true);
    try {
      final ok = await ApiService.verifyEmailCode(
        emailController.text.trim(),
        codeController.text.trim(),
        'RESET_PW',
      );
      if (ok) {
        if (mounted) setState(() => emailVerified = true);
        _snack('이메일 인증이 완료되었습니다');
      } else {
        _snack('인증코드가 올바르지 않습니다');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 비밀번호 재설정
  Future<void> _resetPassword() async {
    if (!emailVerified) {
      _snack('이메일 인증을 완료해주세요');
      return;
    }
    if (userIdController.text.trim().isEmpty) {
      _snack('아이디를 입력해주세요');
      return;
    }
    if (pwController.text.isEmpty || pwConfirmController.text.isEmpty) {
      _snack('새 비밀번호를 입력해주세요');
      return;
    }
    if (pwController.text != pwConfirmController.text) {
      _snack('비밀번호가 일치하지 않습니다');
      return;
    }
    setState(() => loading = true);
    try {
      final result = await ApiService.resetPassword(
        userIdController.text.trim(),
        emailController.text.trim(),
        pwController.text,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _snack('비밀번호가 재설정되었습니다');
        Navigator.pop(context); // 로그인 화면으로
      } else {
        // 서버 메시지 그대로 (예: "아이디와 이메일이 일치하지 않습니다.")
        _snack(
          ApiService.errorText(
            result['body'],
            fallback: '비밀번호 재설정에 실패했어요 · 다시 시도해주세요',
          ),
        );
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      '비밀번호 재설정',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                const Text(
                  '가입한 아이디와 이메일로 본인 확인 후\n새 비밀번호를 설정하세요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // 아이디 (인증 완료 후 잠금)
                TextField(
                  controller: userIdController,
                  enabled: !emailVerified,
                  decoration: _inputStyle('아이디'),
                ),
                const SizedBox(height: 12),

                // 이메일 + 인증요청
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        enabled: !emailVerified,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputStyle('이메일').copyWith(
                          suffixIcon: emailVerified
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1D9E75),
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    emailVerified
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFF5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '인증됨',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          )
                        : _smallButton(
                            codeSent ? '재발송' : '인증 요청',
                            loading ? null : _sendCode,
                          ),
                  ],
                ),

                // 인증코드 입력 (발송 후 ~ 인증 전)
                if (codeSent && !emailVerified) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          decoration: _inputStyle('인증코드 6자리'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _smallButton('확인', loading ? null : _verifyCode),
                    ],
                  ),
                ],

                // 인증 완료 후 새 비번 입력
                if (emailVerified) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwController,
                    obscureText: true,
                    decoration: _inputStyle('새 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwConfirmController,
                    obscureText: true,
                    decoration: _inputStyle('새 비밀번호 확인'),
                  ),
                ],
                const SizedBox(height: 24),

                // 재설정 버튼
                GestureDetector(
                  onTap: loading ? null : _resetPassword,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: (loading || !emailVerified)
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loading ? '처리 중...' : '비밀번호 재설정',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallButton(String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEBF9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF534AB7),
          ),
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}
