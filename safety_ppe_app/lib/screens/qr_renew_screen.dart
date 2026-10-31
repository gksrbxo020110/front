import 'package:flutter/material.dart';

class QrRenewScreen extends StatefulWidget {
  final String currentExpireAt; // 현재 QR 만료일 (2026-07-15T00:00:00 형식)
  const QrRenewScreen({super.key, this.currentExpireAt = ''});

  @override
  State<QrRenewScreen> createState() => _QrRenewScreenState();
}

class _QrRenewScreenState extends State<QrRenewScreen> {
  int selected = 0;

  final List<String> options = const [
    '당일 (오늘 자정 만료)',
    '주간 (7일)',
    '월간 (최대 1개월)',
  ];

  // 선택 인덱스 → 서버에 보낼 유효일수 (당일=1 / 주간=7 / 월간=30)
  final List<int> validDaysList = const [1, 7, 30];

  // 만료일 포맷 (2026-07-15T00:00:00 → 2026.07.15)
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return raw;
    }
  }

  // 남은 일수 계산
  String _daysLeftText(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = d.difference(now).inDays;
      if (diff < 0) return '(만료됨)';
      if (diff == 0) return '(오늘 만료)';
      return '($diff일 남음)';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expireText = _formatDate(widget.currentExpireAt);
    final daysLeft = _daysLeftText(widget.currentExpireAt);

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
                    'QR 갱신',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 빨간 만료 경고
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '현재 QR 만료 임박',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expireText.isEmpty
                              ? '만료 정보를 불러올 수 없습니다'
                              : '$expireText까지 $daysLeft',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
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
                  // 새 유효일수(숫자) 반환: 당일=1 / 주간=7 / 월간=30
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
                    '갱신하기',
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
