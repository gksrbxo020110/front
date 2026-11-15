import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'privacy_policy_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool isManager = true;
  bool agreedPrivacy = false;
  bool emailVerified = false;
  bool _codeSent = false;
  bool _isLoading = false;

  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 아이디 중복 확인
  Future<void> _checkId() async {
    final userId = _idController.text.trim();
    if (userId.isEmpty) {
      _showMessage('아이디를 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final available = await ApiService.checkId(userId: userId);
      if (!mounted) return;
      _showMessage(available ? '사용 가능한 아이디입니다' : '이미 사용 중인 아이디입니다');
    } catch (e) {
      _showMessage('중복 확인에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 닉네임 중복 확인
  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showMessage('닉네임을 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final available = await ApiService.checkNickname(nickname: nickname);
      if (!mounted) return;
      _showMessage(available ? '사용 가능한 닉네임입니다' : '이미 사용 중인 닉네임입니다');
    } catch (e) {
      _showMessage('중복 확인에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('이메일을 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.sendEmailCode(email: email);
      setState(() => _codeSent = true);
      _showMessage('인증 코드가 발송되었습니다');
    } catch (e) {
      _showMessage('이메일 발송에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('인증 코드를 입력하세요');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.verifyEmailCode(email: email, code: code);
      setState(() => emailVerified = true);
      _showMessage('이메일 인증이 완료되었습니다');
    } catch (e) {
      _showMessage('인증 코드가 올바르지 않습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() async {
    final userId = _idController.text.trim();
    final password = _pwController.text.trim();
    final pwConfirm = _pwConfirmController.text.trim();
    final name = _nameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();

    if (userId.isEmpty || password.isEmpty || name.isEmpty || email.isEmpty) {
      _showMessage('필수 항목을 모두 입력하세요');
      return;
    }
    if (password != pwConfirm) {
      _showMessage('비밀번호가 일치하지 않습니다');
      return;
    }
    if (nickname.isEmpty) {
      _showMessage('닉네임을 입력하세요');
      return;
    }
    if (!emailVerified) {
      _showMessage('이메일 인증을 완료하세요');
      return;
    }
    if (!agreedPrivacy) {
      _showMessage('개인정보 수집·이용에 동의해주세요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.signup(
        userId: userId,
        password: password,
        name: name,
        nickname: nickname,
        email: email,
        role: isManager ? 'ADMIN' : 'WORKER',
      );
      if (!mounted) return;
      _showMessage('회원가입이 완료되었습니다');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final raw = e.toString().toLowerCase();
      String msg;
      if (raw.contains('email') || raw.contains('이메일')) {
        msg = '이미 가입된 이메일입니다';
      } else if (raw.contains('userid') ||
          raw.contains('아이디') ||
          raw.contains('id')) {
        msg = '이미 사용 중인 아이디입니다';
      } else if (raw.contains('nickname') || raw.contains('닉네임')) {
        msg = '이미 사용 중인 닉네임입니다';
      } else {
        msg = '회원가입에 실패했습니다 · 입력 정보를 다시 확인해주세요';
      }
      _showMessage(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'AI 스마트 안전 메이트',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '회원가입',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '회원 정보를 입력하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              _buildRoleToggle(),
              const SizedBox(height: 24),

              // 아이디 + 중복확인
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      decoration: const InputDecoration(hintText: '아이디'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _checkId,
                    child: const Text('중복 확인'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwConfirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호 확인'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: '이름'),
              ),

              // 닉네임 (관리자·노동자 모두)
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(hintText: '닉네임'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _checkNickname,
                    child: const Text('중복 확인'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 이메일 + 인증요청
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      enabled: !emailVerified,
                      decoration: const InputDecoration(hintText: '이메일'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: (_isLoading || emailVerified) ? null : _sendCode,
                    child: const Text('인증 요청'),
                  ),
                ],
              ),

              // 코드 입력
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
              const SizedBox(height: 20),

              // 개인정보 동의
              Row(
                children: [
                  Checkbox(
                    value: agreedPrivacy,
                    onChanged: (v) =>
                        setState(() => agreedPrivacy = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                  const Text(
                    '[필수] ',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                  const Text('개인정보 수집·이용 동의', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                      if (result == true) {
                        setState(() => agreedPrivacy = true);
                      }
                    },
                    child: const Text(
                      '보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('가입 완료'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _roleButton(
            '안전관리자',
            isManager,
            () => setState(() => isManager = true),
          ),
          _roleButton(
            '건설노동자',
            !isManager,
            () => setState(() => isManager = false),
          ),
        ],
      ),
    );
  }

  Widget _roleButton(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEDE7F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                const Icon(Icons.check, size: 16, color: AppColors.primary),
              if (selected) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
