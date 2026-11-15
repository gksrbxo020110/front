import 'package:flutter/material.dart';
import '../theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 앱바 (뒤로가기 + 제목)
      appBar: AppBar(
        title: const Text(
          '개인정보 수집·이용 동의',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section(
                        '1. 수집하는 개인정보 항목',
                        '아이디, 비밀번호, 이름, 이메일, 소속현장, 미착용 감지 이미지',
                      ),
                      _section(
                        '2. 수집·이용 목적',
                        '현장 안전 관리, PPE(개인보호구) 착용 감지 및 경고 알림, 안전 통계 제공',
                      ),
                      _section(
                        '3. 보유·이용 기간',
                        '회원 탈퇴 시까지 (관련 법령에 따라 일정 기간 보관될 수 있음)',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '• 동의를 거부할 권리가 있으며, 필수 항목 미동의 시 서비스 이용이 제한됩니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 동의합니다 버튼 → 누르면 회원가입 화면으로 돌아감
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // '동의함(true)'을 갖고 회원가입으로 복귀
                },
                child: const Text('동의합니다'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 제목 + 내용 한 묶음 (반복되는 부분을 함수로)
  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
