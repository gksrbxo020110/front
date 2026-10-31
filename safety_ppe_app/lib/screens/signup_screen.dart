import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';
import 'api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int roleTab = 0;
  bool agreed = false;
  bool codeSent = false;
  bool emailVerified = false;
  bool loading = false;

  // 중복 확인 상태
  bool idChecked = false; // 아이디 중복 확인 통과
  bool nicknameChecked = false; // 닉네임 중복 확인 통과

  final idController = TextEditingController();
  final pwController = TextEditingController();
  final pwConfirmController = TextEditingController();
  final nameController = TextEditingController();
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 아이디 중복 확인
  Future<void> _checkId() async {
    if (idController.text.trim().isEmpty) {
      _snack('아이디를 입력해주세요');
      return;
    }
    setState(() => loading = true);
    try {
      final available = await ApiService.checkUserId(idController.text.trim());
      if (available == true) {
        setState(() => idChecked = true);
        _snack('사용 가능한 아이디입니다');
      } else if (available == false) {
        setState(() => idChecked = false);
        _snack('이미 사용 중인 아이디입니다');
      } else {
        _snack('중복 확인 실패. 다시 시도해주세요');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      setState(() => loading = false);
    }
  }

  // 닉네임 중복 확인
  Future<void> _checkNickname() async {
    if (nicknameController.text.trim().isEmpty) {
      _snack('닉네임을 입력해주세요');
      return;
    }
    setState(() => loading = true);
    try {
      final available = await ApiService.checkNickname(
        nicknameController.text.trim(),
      );
      if (available == true) {
        setState(() => nicknameChecked = true);
        _snack('사용 가능한 닉네임입니다');
      } else if (available == false) {
        setState(() => nicknameChecked = false);
        _snack('이미 사용 중인 닉네임입니다');
      } else {
        _snack('중복 확인 실패. 다시 시도해주세요');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (emailController.text.trim().isEmpty) {
      _snack('이메일을 입력해주세요');
      return;
    }
    setState(() => loading = true);
    try {
      final ok = await ApiService.sendEmailCode(
        emailController.text.trim(),
        'SIGNUP',
      );
      if (ok) {
        setState(() => codeSent = true);
        _snack('인증코드가 이메일로 발송되었습니다');
      } else {
        _snack('인증코드 발송 실패. 이메일을 확인해주세요');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      setState(() => loading = false);
    }
  }

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
        'SIGNUP',
      );
      if (ok) {
        setState(() => emailVerified = true);
        _snack('이메일 인증이 완료되었습니다');
      } else {
        _snack('인증코드가 올바르지 않습니다');
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      setState(() => loading = false);
    }
  }

  // 서버 에러 응답(JSON·에러 페이지 등) → 사용자용 한 줄 문구
  // 서버 메시지: "이미 사용 중인 이메일입니다." / "...아이디입니다." / "...닉네임입니다."
  //            "이메일 인증이 완료되지 않았습니다."
  String _signupErrorMessage(String body) {
    if (body.contains('이메일 인증')) {
      return '이메일 인증이 완료되지 않았어요. 다시 인증해주세요';
    }
    if (body.contains('이메일')) {
      return '이미 가입된 이메일이에요. 다른 이메일을 사용해주세요';
    }
    if (body.contains('아이디')) {
      return '이미 사용 중인 아이디예요. 다른 아이디를 입력해주세요';
    }
    if (body.contains('닉네임')) {
      return '이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해주세요';
    }
    return '회원가입에 실패했어요. 잠시 후 다시 시도해주세요';
  }

  Future<void> _submit() async {
    if (idController.text.trim().isEmpty ||
        pwController.text.isEmpty ||
        pwConfirmController.text.isEmpty ||
        nameController.text.trim().isEmpty ||
        nicknameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      _snack('모든 항목을 입력해주세요');
      return;
    }
    if (!idChecked) {
      _snack('아이디 중복 확인을 해주세요');
      return;
    }
    if (!nicknameChecked) {
      _snack('닉네임 중복 확인을 해주세요');
      return;
    }
    if (pwController.text != pwConfirmController.text) {
      _snack('비밀번호가 일치하지 않습니다');
      return;
    }
    if (!emailVerified) {
      _snack('이메일 인증을 완료해주세요');
      return;
    }
    if (!agreed) {
      _snack('개인정보 수집에 동의해주세요');
      return;
    }

    setState(() => loading = true);
    try {
      final result = await ApiService.signup(
        userId: idController.text.trim(),
        password: pwController.text,
        name: nameController.text.trim(),
        nickname: nicknameController.text.trim(),
        email: emailController.text.trim(),
        role: roleTab == 0 ? 'ADMIN' : 'WORKER',
      );
      if (result['success'] == true) {
        _snack('회원가입이 완료되었습니다');
        Navigator.pop(context);
      } else {
        _snack(_signupErrorMessage(result['body']?.toString() ?? ''));
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
    } finally {
      setState(() => loading = false);
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
                const SizedBox(height: 40),
                const Text(
                  'AI 스마트 안전 메이트',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                const Text(
                  '회원가입',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '회원 정보를 입력하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 20),

                // 역할 탭
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1FB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [_roleTab('안전관리자', 0), _roleTab('건설노동자', 1)],
                  ),
                ),
                const SizedBox(height: 22),

                // 아이디 + 중복확인
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idController,
                        onChanged: (_) =>
                            setState(() => idChecked = false), // 바꾸면 재확인
                        decoration: _inputStyle('아이디').copyWith(
                          suffixIcon: idChecked
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
                    _smallButton('중복 확인', loading ? null : _checkId),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: pwController,
                  obscureText: true,
                  decoration: _inputStyle('비밀번호'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwConfirmController,
                  obscureText: true,
                  decoration: _inputStyle('비밀번호 확인'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: _inputStyle('이름'),
                ),
                const SizedBox(height: 12),

                // 닉네임 + 중복확인
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nicknameController,
                        onChanged: (_) =>
                            setState(() => nicknameChecked = false),
                        decoration: _inputStyle('닉네임').copyWith(
                          suffixIcon: nicknameChecked
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
                    _smallButton('중복 확인', loading ? null : _checkNickname),
                  ],
                ),
                const SizedBox(height: 12),

                // 이메일 + 인증요청
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        enabled: !emailVerified,
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Color(0xFF1D9E75),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '인증됨',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D9E75),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _smallButton(
                            codeSent ? '재발송' : '인증 요청',
                            loading ? null : _sendCode,
                          ),
                  ],
                ),

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

                if (emailVerified) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF1D9E75),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '이메일 인증이 완료되었습니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1D9E75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // 개인정보 동의
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => agreed = !agreed),
                      child: Icon(
                        agreed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 22,
                        color: agreed
                            ? const Color(0xFF7F77DD)
                            : const Color(0xFFB0B0B0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '[필수] ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE24B4A),
                      ),
                    ),
                    const Text('개인정보 수집·이용동의', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                        if (result == true) setState(() => agreed = true);
                      },
                      child: const Text(
                        '보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 가입 완료
                GestureDetector(
                  onTap: loading ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loading ? '처리 중...' : '가입 완료',
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

  Widget _roleTab(String label, int index) {
    final bool sel = roleTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => roleTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFD6D1F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sel) ...[
                const Icon(Icons.check, size: 15, color: Color(0xFF534AB7)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel
                      ? const Color(0xFF534AB7)
                      : const Color(0xFF9A9A9A),
                ),
              ),
            ],
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
