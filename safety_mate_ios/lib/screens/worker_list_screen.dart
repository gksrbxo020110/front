import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'worker_detail_screen.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  List<dynamic> _allWorkers = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getManagerDashboard();
      if (!mounted) return;
      setState(() {
        _allWorkers = (data['workers'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('노동자 목록 조회 실패: $e')));
    }
  }

  String _gradeKorean(String? grade) {
    switch (grade) {
      case 'RED':
        return '레드';
      case 'YELLOW':
        return '옐로';
      case 'GREEN':
        return '그린';
      default:
        return '그린';
    }
  }

  // 검색어로 필터링
  List<dynamic> get _filtered {
    if (_query.trim().isEmpty) return _allWorkers;
    final q = _query.trim();
    return _allWorkers.where((w) {
      final name = (w['name'] ?? '').toString();
      final nick = (w['nickname'] ?? '').toString();
      return name.contains(q) || nick.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final workers = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '전체 노동자',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: '이름 또는 닉네임 검색',
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '총 ${_allWorkers.length}명 · 레드 우선 정렬',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 노동자 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : workers.isEmpty
                  ? const Center(
                      child: Text(
                        '노동자가 없습니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: workers.length,
                      itemBuilder: (context, index) {
                        return _workerCard(context, workers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workerCard(BuildContext context, dynamic w) {
    final grade = _gradeKorean(w['grade'] as String?);
    final name = w['name'] ?? '';
    final nick = w['nickname'] ?? '';
    final userId = w['userId'] ?? '';
    final count = w['violationCount'] ?? 0;

    Color dotColor;
    Color bgColor;
    Color textColor = AppColors.textPrimary;
    switch (grade) {
      case '레드':
        dotColor = AppColors.danger;
        bgColor = AppColors.danger;
        textColor = Colors.white;
        break;
      case '옐로':
        dotColor = AppColors.warning;
        bgColor = const Color(0xFFEDE7F6);
        break;
      default:
        dotColor = AppColors.safe;
        bgColor = const Color(0xFFEDE7F6);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerDetailScreen(
              targetUserId: userId,
              name: name,
              nick: nick,
              grade: grade,
              count: count,
            ),
          ),
        ).then((_) => _load()); // 소속 해제하고 오면 새로고침
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name · $nick',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$grade · 미착용 $count건',
                    style: TextStyle(
                      fontSize: 12,
                      color: grade == '레드'
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: grade == '레드' ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
