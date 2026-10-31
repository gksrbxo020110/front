import 'package:flutter/material.dart';
import 'detection_result_screen.dart';
import 'api_service.dart';

class WorkerStatusScreen extends StatefulWidget {
  final bool isTab; // 탭으로 열림=뒤로가기 없음
  const WorkerStatusScreen({super.key, this.isTab = false});

  @override
  State<WorkerStatusScreen> createState() => _WorkerStatusScreenState();
}

class _WorkerStatusScreenState extends State<WorkerStatusScreen> {
  bool loading = true;
  String grade = 'GREEN';
  int violationCount = 0;
  String myName = ''; // 결과 화면에 표시할 내 이름
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 미착용 항목이 하나라도 있는 기록인지
  // (iOS가 저장한 '착용 완료' 기록은 notWornItems가 비어 있음 → 이력에서 제외)
  bool _hasNotWorn(dynamic h) {
    final items = (h is Map) ? h['notWornItems'] : null;
    if (items is! List) return false;
    return items.any((e) => e.toString().trim().isNotEmpty);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final result = await ApiService.getWorkerDashboard();
    if (!mounted) return;

    if (result['success'] == true) {
      final List rawHistory = result['history'] ?? [];
      final list = rawHistory
          .where(_hasNotWorn) // 착용 완료 기록 제외 → 누적 숫자와 목록 개수 일치
          .map<Map<String, dynamic>>(
            (h) => {
              'summary': h['summary']?.toString() ?? '미착용',
              'detectedAt': h['detectedAt']?.toString() ?? '',
              'workType': h['workType']?.toString() ?? '',
              'detectionMode': h['detectionMode']?.toString() ?? '',
              // 기록 전체 (결과 화면에서 사진·체크리스트 표시용)
              'record': Map<String, dynamic>.from(h),
            },
          )
          .toList();
      setState(() {
        grade = result['grade']?.toString() ?? 'GREEN';
        violationCount = result['violationCount'] ?? 0;
        myName = result['name']?.toString() ?? '';
        history = list;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  // 이번 달 미착용 건수 (미착용 이력 중 이번 달 기록만 셈)
  int get _thisMonthCount {
    final now = DateTime.now();
    int count = 0;
    for (final h in history) {
      try {
        final d = DateTime.parse(h['detectedAt'] as String);
        if (d.year == now.year && d.month == now.month) count++;
      } catch (_) {
        // 날짜 형식이 이상하면 세지 않음
      }
    }
    return count;
  }

  // 이력 카드 탭 → 감지 결과 화면(14번)
  void _openResult(Map<String, dynamic> h) {
    final record = h['record'];
    if (record is! Map<String, dynamic>) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetectionResultScreen.fromRecord(record, workerName: myName),
      ),
    );
  }

  // 등급 한글
  String get _gradeKo {
    switch (grade) {
      case 'RED':
        return '레드';
      case 'YELLOW':
        return '옐로';
      case 'GREEN':
      default:
        return '그린';
    }
  }

  // 등급 카드 배경색
  Color get _cardColor {
    switch (grade) {
      case 'RED':
        return const Color(0xFFFCEBEB);
      case 'YELLOW':
        return const Color(0xFFFDF3E0);
      case 'GREEN':
      default:
        return const Color(0xFFDFF5E1);
    }
  }

  // 등급 점 색상
  Color get _dotColor {
    switch (grade) {
      case 'RED':
        return const Color(0xFFE24B4A);
      case 'YELLOW':
        return const Color(0xFFBA7517);
      case 'GREEN':
      default:
        return const Color(0xFF3B7D3F);
    }
  }

  // 등급 설명 문구 색
  Color get _descColor {
    switch (grade) {
      case 'RED':
        return const Color(0xFFA32D2D);
      case 'YELLOW':
        return const Color(0xFF8A5A11);
      case 'GREEN':
      default:
        return const Color(0xFF3B6D11);
    }
  }

  // 등급 설명 문구 ('누적'으로 통일)
  String get _descText {
    if (violationCount == 0) {
      return '누적 미착용 0건 · 양호';
    }
    return '누적 미착용 $violationCount건';
  }

  // 날짜 포맷 (2026-07-08T09:41 → 07.08)
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // 앱바 (탭이면 뒤로가기 없음)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!widget.isTab)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.arrow_back, size: 24),
                              ),
                            ),
                          const Text(
                            '내 안전 현황',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── 안전 등급 카드 (등급별 색) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '현재 안전 등급',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.circle, size: 16, color: _dotColor),
                                const SizedBox(width: 8),
                                Text(
                                  _gradeKo,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _descText,
                              style: TextStyle(fontSize: 12, color: _descColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── 통계 2개 (둘 다 서버 데이터 기준) ──
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              number: '$violationCount',
                              label: '누적 미착용',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              number: '$_thisMonthCount',
                              label: '이번 달 미착용',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── 미착용 이력 (착용 완료 기록 제외) ──
                      const Text(
                        '미착용 이력',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (history.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: const Text(
                            '미착용 이력이 없습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        )
                      else
                        ...history.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HistoryItem(
                              ppe: h['summary'],
                              date: _formatDate(h['detectedAt']),
                              onTap: () => _openResult(h),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// 통계 박스
class _StatBox extends StatelessWidget {
  final String number;
  final String label;
  const _StatBox({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
        ],
      ),
    );
  }
}

// 미착용 이력 항목 (누르면 감지 결과 화면)
class _HistoryItem extends StatelessWidget {
  final String ppe;
  final String date;
  final VoidCallback onTap;
  const _HistoryItem({
    required this.ppe,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ppe,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC4C4C4)),
          ],
        ),
      ),
    );
  }
}
