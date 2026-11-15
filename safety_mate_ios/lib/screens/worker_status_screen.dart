import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class WorkerStatusScreen extends StatefulWidget {
  const WorkerStatusScreen({super.key});

  @override
  State<WorkerStatusScreen> createState() => _WorkerStatusScreenState();
}

class _WorkerStatusScreenState extends State<WorkerStatusScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getWorkerDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현황 조회 실패: $e')));
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

  Color _gradeColor(String grade) {
    switch (grade) {
      case '레드':
        return AppColors.danger;
      case '옐로':
        return AppColors.warning;
      default:
        return AppColors.safe;
    }
  }

  // 등급별 큰 카드 배경색 (연한 톤)
  Color _gradeBgColor(String grade) {
    switch (grade) {
      case '레드':
        return const Color(0xFFFFCDD2);
      case '옐로':
        return const Color(0xFFFFF9C4);
      default:
        return const Color(0xFFC8E6C9);
    }
  }

  String _gradeDesc(String grade, int count) {
    switch (grade) {
      case '레드':
        return '미착용 $count건 · 주의 필요';
      case '옐로':
        return '미착용 $count건 · 경고';
      default:
        return '미착용 $count건 · 안전';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}.${two(dt.month)}.${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? {};
    final grade = _gradeKorean(d['grade'] as String?);
    final count = d['violationCount'] ?? 0;
    final history = (d['history'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '내 안전 현황',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 컬러링 등급 큰 카드
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          color: _gradeBgColor(grade),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '현재 안전 등급',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              grade,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _gradeColor(grade),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _gradeDesc(grade, count),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 누적 미착용
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '누적 미착용',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 미착용 이력
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
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: const Text(
                            '미착용 이력이 없습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        ...history.map((h) => _historyItem(h)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _historyItem(dynamic h) {
    final summary = h['summary'] ?? '미착용';
    final mode = h['detectionMode'] ?? '';
    final workType = h['workType'];
    final date = _formatDate(h['detectedAt'] as String?);
    final s3Key = h['s3Key'] as String?;
    final modeKorean = mode == 'GATE' ? 'Gate' : 'Inspection';
    final source = workType != null ? '$modeKorean · $workType' : modeKorean;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: s3Key != null ? () => _showImageDialog(s3Key) : null,
            child: _thumbnail(s3Key),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(String? s3Key) {
    if (s3Key == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, color: Colors.white24, size: 28),
      );
    }
    return FutureBuilder<String?>(
      future: ApiService.getS3ViewUrl(s3Key: s3Key),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 28,
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                )
              : const Icon(Icons.image, color: Colors.white24, size: 28),
        );
      },
    );
  }

  void _showImageDialog(String s3Key) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: FutureBuilder<String?>(
          future: ApiService.getS3ViewUrl(s3Key: s3Key),
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (url == null) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            return InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    '이미지를 불러올 수 없습니다',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
