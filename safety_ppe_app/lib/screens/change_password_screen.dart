import 'package:flutter/material.dart';
import 'api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentPwController = TextEditingController();
  final newPwController = TextEditingController();
  final newPwConfirmController = TextEditingController();
  bool loading = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _changePassword() async {
    if (currentPwController.text.isEmpty ||
        newPwController.text.isEmpty ||
        newPwConfirmController.text.isEmpty) {
      _snack('모든 항목을 입력해주세요');
      return;
    }
    if (newPwController.text != newPwConfirmController.text) {
      _snack('새 비밀번호가 일치하지 않습니다');
      return;
    }
    if (currentPwController.text == newPwController.text) {
      _snack('현재 비밀번호와 다른 비밀번호를 입력해주세요');
      return;
    }

    setState(() => loading = true);
    try {
      final result = await ApiService.changePassword(
        currentPwController.text,
        newPwController.text,
      );
      if (result['success'] == true) {
        _snack('비밀번호가 변경되었습니다');
        Navigator.pop(context);
      } else {
        _snack('변경 실패: 현재 비밀번호를 확인해주세요');
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
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                const Text(
                  '현재 비밀번호를 확인한 후\n새 비밀번호를 설정하세요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: currentPwController,
                  obscureText: true,
                  decoration: _inputStyle('현재 비밀번호'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwController,
                  obscureText: true,
                  decoration: _inputStyle('새 비밀번호'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwConfirmController,
                  obscureText: true,
                  decoration: _inputStyle('새 비밀번호 확인'),
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: loading ? null : _changePassword,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loading ? '처리 중...' : '비밀번호 변경',
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
