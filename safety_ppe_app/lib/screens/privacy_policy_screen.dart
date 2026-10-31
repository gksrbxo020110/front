import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 앱바 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // 동의 안 하고 뒤로
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '개인정보 수집·이용 동의',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // ── 내용 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _section(
                      '1. 수집하는 개인정보 항목',
                      '아이디, 비밀번호, 이름, 이메일, 소속현장, 작업종류, 미착용 감지 이미지',
                    ),
                    const SizedBox(height: 22),
                    _section(
                      '2. 수집·이용 목적',
                      '현장 안전 관리, PPE(개인보호구) 착용 감지 및 경고 알림, 안전 통계 제공',
                    ),
                    const SizedBox(height: 22),
                    _section(
                      '3. 보유·이용 기간',
                      '회원 탈퇴 시까지 (관련 법령에 따라 일정 기간 보관될 수 있음)',
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      '• 동의를 거부할 권리가 있으며, 필수 항목 미동의 시 서비스 이용이 제한됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B6B),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ── 동의 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: GestureDetector(
                onTap: () {
                  // 동의 → true 반환하며 회원가입으로 복귀
                  Navigator.pop(context, true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '동의합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6B6B),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
