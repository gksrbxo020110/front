import 'package:flutter/material.dart';
import 'worker_list_screen.dart';
import 'worker_detail_screen.dart';
import 'api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  String siteName = '';
  int greenCount = 0;
  int yellowCount = 0;
  int redCount = 0;
  int todayViolationCount = 0;
  List<Map<String, dynamic>> workers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 등급 한글 변환 (GREEN/YELLOW/RED → 그린/옐로/레드)
  String _gradeKo(String? grade) {
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

  // 등급 색상
  Color _gradeColor(String? grade) {
    switch (grade) {
      case 'RED':
        return const Color(0xFFE24B4A);
      case 'YELLOW':
        return const Color(0xFFBA7517);
      case 'GREEN':
      default:
        return const Color(0xFF639922);
    }
  }

  // 등급 정렬 순서 (레드 우선)
  int _gradeOrder(String? grade) {
    switch (grade) {
      case 'RED':
        return 0;
      case 'YELLOW':
        return 1;
      case 'GREEN':
      default:
        return 2;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final result = await ApiService.getManagerDashboard();
    if (!mounted) return;

    if (result['success'] == true) {
      final List rawWorkers = result['workers'] ?? [];
      final list = rawWorkers
          .map<Map<String, dynamic>>(
            (w) => {
              'userId': w['userId']?.toString() ?? '',
              'name': w['name']?.toString() ?? '',
              'nickname': w['nickname']?.toString() ?? '',
              'violationCount': w['violationCount'] ?? 0,
              'grade': w['grade']?.toString() ?? 'GREEN',
            },
          )
          .toList();
      // 레드 우선 정렬
      list.sort(
        (a, b) => _gradeOrder(a['grade']).compareTo(_gradeOrder(b['grade'])),
      );

      setState(() {
        siteName = result['siteName']?.toString() ?? '';
        greenCount = result['greenCount'] ?? 0;
        yellowCount = result['yellowCount'] ?? 0;
        redCount = result['redCount'] ?? 0;
        todayViolationCount = result['todayViolationCount'] ?? 0;
        workers = list;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWorkers = greenCount + yellowCount + redCount;
    // 미리보기용 상위 3명
    final preview = workers.take(3).toList();

    return Scaffold(
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
                      const SizedBox(height: 12),
                      const Text(
                        '대시보드',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        siteName.isEmpty ? '소속 현장 없음' : siteName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F77DD),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 컬러링 현황 (서버 연동)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '컬러링 현황 · 노동자 $totalWorkers명',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _GradeBig(
                                  count: '$greenCount',
                                  label: '그린',
                                  color: const Color(0xFF639922),
                                ),
                                _GradeBig(
                                  count: '$yellowCount',
                                  label: '옐로',
                                  color: const Color(0xFFBA7517),
                                ),
                                _GradeBig(
                                  count: '$redCount',
                                  label: '레드',
                                  color: const Color(0xFFE24B4A),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            '노동자 목록',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '· 레드 우선',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 노동자 카드 미리보기 (서버 연동, 상위 3명)
                      if (preview.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: const Text(
                            '등록된 노동자가 없습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        )
                      else
                        ...preview.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WorkerPreview(
                              userId: w['userId'],
                              name: w['name'],
                              nick: w['nickname'],
                              grade: _gradeKo(w['grade']),
                              count: w['violationCount'],
                              color: _gradeColor(w['grade']),
                              onReturn: _load, // 상세에서 돌아오면 새로고침
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),

                      // 전체 보기 (클릭 → 전체 목록, 돌아오면 새로고침)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkerListScreen(),
                            ),
                          ).then((_) => _load());
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCECBF6)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '전체 $totalWorkers명 보기 ›',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF534AB7),
                            ),
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

class _GradeBig extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _GradeBig({
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
        ),
      ],
    );
  }
}

// 대시보드 노동자 미리보기 카드 (클릭 → 상세)
class _WorkerPreview extends StatelessWidget {
  final String userId;
  final String name;
  final String nick;
  final String grade;
  final int count;
  final Color color;
  final VoidCallback onReturn; // 상세에서 돌아왔을 때 (새로고침)
  const _WorkerPreview({
    required this.userId,
    required this.name,
    required this.nick,
    required this.grade,
    required this.count,
    required this.color,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRed = grade == '레드';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerDetailScreen(
              userId: userId,
              name: name,
              nick: nick,
              grade: grade,
              count: count,
              color: color,
            ),
          ),
        ).then((_) => onReturn());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isRed ? const Color(0xFFFDF4F4) : Colors.white,
          border: Border.all(
            color: isRed ? const Color(0xFFE24B4A) : const Color(0xFFE5E5E5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isRed
                              ? const Color(0xFFA32D2D)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (nick.isNotEmpty)
                        Text(
                          ' · $nick',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$grade · 미착용 $count건',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC4C4C4)),
          ],
        ),
      ),
    );
  }
}
