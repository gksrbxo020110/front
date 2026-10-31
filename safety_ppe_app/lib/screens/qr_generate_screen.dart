import 'package:flutter/material.dart';

class QrGenerateScreen extends StatefulWidget {
  const QrGenerateScreen({super.key});

  @override
  State<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends State<QrGenerateScreen> {
  int selected = 0; // 0=당일, 1=주간, 2=월간

  final List<String> options = const [
    '당일 (오늘 자정 만료)',
    '주간 (7일)',
    '월간 (최대 1개월)',
  ];

  // 선택 인덱스 → 서버에 보낼 유효일수 (당일=1 / 주간=7 / 월간=30)
  final List<int> validDaysList = const [1, 7, 30];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
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
                    'QR 생성',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 파란 안내
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6FA8F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR 코드를 생성하세요',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '현장 입장 시 사용됩니다',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '유효기간 선택',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 10),
              ..._buildOptions(),

              const Spacer(),

              GestureDetector(
                onTap: () {
                  // 유효일수(숫자) 반환: 당일=1 / 주간=7 / 월간=30
                  Navigator.pop(context, validDaysList[selected]);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '생성하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    return List.generate(options.length, (i) {
      final bool sel = selected == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => setState(() => selected = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: sel ? const Color(0xFF6FA8F5) : const Color(0xFFE5E5E5),
                width: sel ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(options[i], style: const TextStyle(fontSize: 14)),
                const Spacer(),
                if (sel)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF6FA8F5),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
