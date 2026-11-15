import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'worker_list_screen.dart';
import 'worker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getManagerDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  // 등급 문자열 → 한글
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _errorView()
              : _content(),
        ),
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      children: [
        const SizedBox(height: 200),
        Center(
          child: Text(
            '대시보드를 불러오지 못했습니다\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final d = _data ?? {};
    final siteName = d['siteName'] ?? '소속 현장 없음';
    final green = d['greenCount'] ?? 0;
    final yellow = d['yellowCount'] ?? 0;
    final red = d['redCount'] ?? 0;
    final todayViolation = d['todayViolationCount'] ?? 0;
    final workers = (d['workers'] as List?) ?? [];
    final totalCount = workers.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            '대시보드',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            siteName,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 오늘 미착용 건수 요약
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Text(
                  '오늘 미착용 발생',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$todayViolation건',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 컬러링 현황 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '컬러링 현황 · 노동자 $totalCount명',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _colorCount('$green', '그린', AppColors.safe),
                    _colorCount('$yellow', '옐로', AppColors.warning),
                    _colorCount('$red', '레드', AppColors.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 노동자 목록 · 레드 우선
          const Text(
            '노동자 목록 · 레드 우선',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '등록된 노동자가 없습니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            // 상위 3명만 카드로
            ...workers.take(3).map((w) => _workerCard(context, w)),

            // 전체 보기 (3명 넘으면)
            if (workers.length > 3)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkerListScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '전체 $totalCount명 +',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _colorCount(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerCard(BuildContext context, dynamic w) {
    final gradeStr = w['grade'] as String?; // "RED"/"YELLOW"/"GREEN"
    final grade = _gradeKorean(gradeStr);
    final count = w['violationCount'] ?? 0;
    final name = w['name'] ?? '';
    final nick = w['nickname'] ?? '';
    final userId = w['userId'] ?? '';

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
        ).then((_) => _load()); // 소속 해제하고 돌아오면 목록 새로고침
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
