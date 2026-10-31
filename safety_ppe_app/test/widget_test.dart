import 'package:flutter/material.dart';

void main() {
  runApp(const SafetyApp());
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 스마트 안전 메이트',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: const ManagerHomeScreen(),
    );
  }
}

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── 본문 ──
      body: SafeArea(
        child: SingleChildScrollView(
          // 내용 길어지면 스크롤 가능
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── 헤더 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '안녕하세요, 관리자님',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'AI 스마트 안전 메이트',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.settings, color: Color(0xFF6B6B6B)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 현장 선택기 ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Color(0xFF7F77DD),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '신한 제2공사 현장',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.keyboard_arrow_down, color: Color(0xFF9A9A9A)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 오늘 현황 카드 ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '오늘 현장 현황',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _GradeStat(
                            count: '12',
                            label: '그린',
                            color: Color(0xFF639922),
                          ),
                          _GradeStat(
                            count: '3',
                            label: '옐로',
                            color: Color(0xFFBA7517),
                          ),
                          _GradeStat(
                            count: '1',
                            label: '레드',
                            color: Color(0xFFE24B4A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ── 소제목 ──
                const Text(
                  '감지 모드 선택',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 10),

                // ── Gate 카드 (검정, 주요) ──
                _ModeCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Gate 모드',
                  subtitle: 'QR 스캔 · 무인 입장 체크',
                  filled: true,
                ),
                const SizedBox(height: 10),

                // ── Inspection 카드 (테두리, 보조) ──
                _ModeCard(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Inspection 모드',
                  subtitle: '관리자 순찰 점검',
                  filled: false,
                ),
                const SizedBox(height: 22),

                // ── 현장 코드 관리 버튼 ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1A1A1A)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '현장 코드 관리',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),

      // ── 하단 네비게이션 ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // 홈 탭 활성
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A1A1A),
        unselectedItemColor: const Color(0xFFB0B0B0),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '대시보드'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

// ── 현황 숫자 1개 ──
class _GradeStat extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _GradeStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
        ),
      ],
    );
  }
}

// ── 감지 모드 카드 (Gate/Inspection 재사용) ──
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled; // true=검정 꽉찬, false=테두리
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? const Color(0xFF1A1A1A) : Colors.white;
    final Color fg = filled ? Colors.white : const Color(0xFF1A1A1A);
    final Color sub = filled
        ? const Color(0xFFB8B8B8)
        : const Color(0xFF9A9A9A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: filled
            ? null
            : Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: fg),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right,
            color: filled ? const Color(0xFF6B6B6B) : const Color(0xFFC4C4C4),
          ),
        ],
      ),
    );
  }
}
