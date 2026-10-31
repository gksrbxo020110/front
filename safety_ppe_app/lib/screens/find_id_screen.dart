import 'package:flutter/material.dart';
import 'api_service.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  final emailController = TextEditingController();
  bool loading = false;
  String? foundResult; // 찾은 결과 메시지

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 아이디 찾기 (인증 없이 이메일만)
  Future<void> _findId() async {
    if (emailController.text.trim().isEmpty) {
      _snack('이메일을 입력해주세요');
      return;
    }
    setState(() {
      loading = true;
      foundResult = null;
    });
    try {
      final result = await ApiService.findId(emailController.text.trim());
      if (result['success'] == true) {
        setState(() => foundResult = result['body']); // "회원님의 아이디는 [xxx] 입니다."
      } else {
        _snack('가입된 아이디를 찾을 수 없습니다');
      }
    } catch (e) {
      _snack('서버 연결 실패: $e');
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
                      '아이디 찾기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                const Text(
                  '가입 시 등록한 이메일을 입력하세요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  '이메일로 가입된 아이디를 찾아드립니다',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 20),

                // 이메일 입력
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputStyle('이메일'),
                ),
                const SizedBox(height: 20),

                // 아이디 찾기 버튼
                GestureDetector(
                  onTap: loading ? null : _findId,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loading ? '찾는 중...' : '아이디 찾기',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // 찾은 결과 표시
                if (foundResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F1FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF534AB7),
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          foundResult!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF534AB7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '로그인하러 가기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
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
    );
  }
}
