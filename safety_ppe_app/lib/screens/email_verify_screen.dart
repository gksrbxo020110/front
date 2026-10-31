import 'dart:async';
import 'package:flutter/material.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final codeController = TextEditingController();
  static const String correctCode = '123456'; // 테스트용 인증번호

  Timer? _timer;
  int secondsLeft = 180; // 3:00

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => secondsLeft = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 0) {
        t.cancel();
        setState(() {});
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 화면 나가면 타이머 정리
    super.dispose();
  }

  // 3:00 형식으로 변환
  String get timeText {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _verify() {
    if (secondsLeft <= 0) {
      _snack('인증 시간이 만료되었습니다. 재발송해주세요');
      return;
    }
    if (codeController.text.trim() == correctCode) {
      _timer?.cancel();
      _snack('인증되었습니다');
      Navigator.pop(context, true); // 인증 성공 → true 반환
    } else {
      _snack('인증번호가 일치하지 않습니다');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool expired = secondsLeft <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 70),
                const Text(
                  'AI 스마트 안전 메이트',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 60),

                const Text(
                  '이메일 인증',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '이메일로 전송된 인증 코드를 입력하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 30),

                // ── 인증코드 입력 + 타이머 ──
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: '인증코드 6자리 입력',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 14,
                          ),
                          counterText: '', // 글자수 카운터 숨김
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A1A1A),
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 타이머
                    Text(
                      expired ? '만료' : timeText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: expired
                            ? const Color(0xFFE24B4A)
                            : const Color(0xFF7F77DD),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 확인 버튼
                GestureDetector(
                  onTap: _verify,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '확인',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 재발송
                GestureDetector(
                  onTap: () {
                    _startTimer(); // 타이머 리셋
                    _snack('인증번호가 재발송되었습니다 (테스트: 123456)');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    '인증번호 재발송',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
