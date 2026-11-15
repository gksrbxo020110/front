import 'package:flutter/material.dart';
import '../theme.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final TextEditingController codeController = TextEditingController();

  void _verify() {
    final code = codeController.text.trim();

    if (code == '123456') {
      // 성공: 스낵바 띄우고 잠시 후 이전 화면으로
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증이 완료되었습니다'),
          backgroundColor: AppColors.safe, // 초록
          duration: Duration(seconds: 1),
        ),
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      // 실패: 빨간 스낵바
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증코드가 일치하지 않습니다'),
          backgroundColor: AppColors.danger, // 빨강
          duration: Duration(seconds: 2),
        ),
      );
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
                '이메일 인증',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '이메일로 전송된 인증 코드를 입력하세요',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '인증코드 6자리 입력',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '3:00',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(onPressed: _verify, child: const Text('확인')),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('인증번호를 재발송했습니다'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text(
                  '인증번호 재발송',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
