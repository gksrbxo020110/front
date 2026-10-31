import 'package:flutter/material.dart';
import 'worker_detail_screen.dart';
import 'api_service.dart';

class Worker {
  final String userId;
  final String name;
  final String nick;
  final String grade; // 한글: 레드/옐로/그린
  final int count;
  final Color color;
  const Worker(
    this.userId,
    this.name,
    this.nick,
    this.grade,
    this.count,
    this.color,
  );
}

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final searchController = TextEditingController();
  String keyword = '';

  bool loading = true;
  List<Worker> allWorkers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 등급 한글
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

  // 등급 색
  Color _gradeColor(String? grade) {
    switch (grade) {
      case 'RED':
        return const Color(0xFFE24B4A);
      case 'YELLOW':
        return const Color(0xFFEFC027);
      case 'GREEN':
      default:
        return const Color(0xFF5FBB46);
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
    setState(() => loading = true);
    final result = await ApiService.getManagerDashboard();
    if (result['success'] == true) {
      final List raw = result['workers'] ?? [];
      final list = raw.map<Worker>((w) {
        final gradeRaw = w['grade']?.toString() ?? 'GREEN';
        return Worker(
          w['userId']?.toString() ?? '',
          w['name']?.toString() ?? '',
          w['nickname']?.toString() ?? '',
          _gradeKo(gradeRaw),
          w['violationCount'] ?? 0,
          _gradeColor(gradeRaw),
        );
      }).toList();
      // 레드 우선 정렬
      list.sort((a, b) {
        // 한글 등급 → 원래 순서로 비교
        int order(String g) {
          if (g == '레드') return 0;
          if (g == '옐로') return 1;
          return 2;
        }

        return order(a.grade).compareTo(order(b.grade));
      });

      setState(() {
        allWorkers = list;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  List<Worker> get filtered {
    if (keyword.trim().isEmpty) return allWorkers;
    final k = keyword.trim();
    return allWorkers
        .where((w) => w.name.contains(k) || w.nick.contains(k))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, size: 26),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '전체 노동자',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 검색창
              TextField(
                controller: searchController,
                onChanged: (v) => setState(() => keyword = v),
                decoration: InputDecoration(
                  hintText: '이름 또는 닉네임 검색',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9A9A9A),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF7F77DD)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '총 ${allWorkers.length}명 · 레드 우선 정렬',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7F77DD),
                        ),
                      )
                    : list.isEmpty
                    ? Center(
                        child: Text(
                          keyword.trim().isEmpty
                              ? '등록된 노동자가 없습니다'
                              : '검색 결과가 없습니다',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          ...list.map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _WorkerRow(worker: w),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  final Worker worker;
  const _WorkerRow({required this.worker});

  @override
  Widget build(BuildContext context) {
    final bool isRed = worker.grade == '레드';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerDetailScreen(
              userId: worker.userId,
              name: worker.name,
              nick: worker.nick,
              grade: worker.grade,
              count: worker.count,
              color: worker.color,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isRed ? const Color(0xFFE24B4A) : const Color(0xFFF6F5FC),
          border: isRed ? null : Border.all(color: const Color(0xFFE0DEF5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isRed ? Colors.white : worker.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        worker.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isRed ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        ' · ${worker.nick}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isRed
                              ? Colors.white70
                              : const Color(0xFF9A9A9A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${worker.grade} · 미착용 ${worker.count}건',
                    style: TextStyle(
                      fontSize: 11,
                      color: isRed ? Colors.white70 : const Color(0xFF9A9A9A),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isRed ? Colors.white : const Color(0xFFC4C4C4),
            ),
          ],
        ),
      ),
    );
  }
}
