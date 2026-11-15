import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _resultMessage; // 서버가 준 결과 메시지

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _findId() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('이메일을 입력하세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = null;
    });
    try {
      final message = await ApiService.findId(email: email);
      if (!mounted) return;
      setState(() => _resultMessage = message);
    } catch (e) {
      _showMessage('아이디를 찾을 수 없습니다. 이메일을 확인하세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              const SizedBox(height: 16),
              const Text(
                '아이디 찾기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '가입 시 등록한 이메일을 입력하세요',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // 이메일 입력
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: '이메일 입력'),
              ),
              const SizedBox(height: 16),

              // 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _findId,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('확인'),
              ),

              // 결과 영역
              if (_resultMessage != null) ...[
                const SizedBox(height: 32),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '조회 결과',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _resultMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
