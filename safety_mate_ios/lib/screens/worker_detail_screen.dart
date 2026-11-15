import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../services/api_service.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String targetUserId;
  final String name;
  final String nick;
  final String grade;
  final int count;

  const WorkerDetailScreen({
    super.key,
    required this.targetUserId,
    required this.name,
    required this.nick,
    required this.grade,
    required this.count,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _removing = false;
  bool _unblocking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getWorkerDetailByAdmin(
        targetUserId: widget.targetUserId,
      );
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
      ).showSnackBar(SnackBar(content: Text('상세 조회 실패: $e')));
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
        return widget.grade;
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
    final name = d['name'] ?? widget.name;
    final grade = _gradeKorean(d['grade'] as String?);
    final count = d['violationCount'] ?? widget.count;
    final history = (d['history'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '노동자 상세',
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
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // 프로필 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _gradeColor(grade),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$name · ${widget.nick}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$grade · 누적 미착용 $count건',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (grade == '레드')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '안전등급 위험으로 현장 출입이 제한된 상태입니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 24),

                    if (grade == '레드') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.safe,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.lock_open_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          _unblocking ? '해제 중...' : '출입 차단 해제',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: _unblocking ? null : () => _unblockWorker(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.person_remove_outlined,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      label: const Text(
                        '노동자 삭제 (소속 해제)',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onPressed: _removing ? null : () => _showRemoveDialog(),
                    ),
                    const SizedBox(height: 20),
                  ],
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
            onTap: () => _showImageDialog(h),
            child: _historyThumbnail(s3Key),
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

  Widget _historyThumbnail(String? s3Key) {
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

  // 이미지 크게 보기 + 공유 (관리자 화면)
  void _showImageDialog(dynamic h) {
    final s3Key = h['s3Key'] as String?;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: s3Key == null
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        '이미지가 없습니다',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : FutureBuilder<String?>(
                      future: ApiService.getS3ViewUrl(s3Key: s3Key),
                      builder: (context, snapshot) {
                        final url = snapshot.data;
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: () => _shareHistory(h),
                icon: const Icon(Icons.share, size: 18, color: Colors.white),
                label: const Text(
                  '공유하기',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 미착용 이력 공유 (이미지 + 문구)
  Future<void> _shareHistory(dynamic h) async {
    final summary = h['summary'] ?? '미착용';
    final mode = h['detectionMode'] ?? '';
    final workType = h['workType'];
    final date = _formatDate(h['detectedAt'] as String?);
    final s3Key = h['s3Key'] as String?;
    final modeKorean = mode == 'GATE' ? 'Gate' : 'Inspection';
    final source = workType != null ? '$modeKorean · $workType' : modeKorean;

    final text =
        '[AI 스마트 안전 메이트] 감지 결과\n'
        '${widget.name} · $source · $date\n'
        '$summary';

    try {
      if (s3Key != null) {
        final url = await ApiService.getS3ViewUrl(s3Key: s3Key);
        if (url != null) {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200) {
            final dir = await getTemporaryDirectory();
            final file = File(
              '${dir.path}/detection_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(resp.bodyBytes);
            await Share.shareXFiles([XFile(file.path)], text: text);
            return;
          }
        }
      }
      await Share.share(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
    }
  }

  void _showRemoveDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_remove_outlined,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.name} 님을 삭제할까요?',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '해당 노동자의 현장 소속이 해제되며\n되돌릴 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _removeWorker();
              },
              child: const Text('삭제'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeWorker() async {
    setState(() => _removing = true);
    try {
      await ApiService.removeWorker(targetUserId: widget.targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.name} 님이 삭제되었습니다'),
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _unblockWorker() async {
    setState(() => _unblocking = true);
    try {
      await ApiService.unblockWorker(targetUserId: widget.targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.name} 님의 출입 차단이 해제되었습니다'),
          backgroundColor: AppColors.safe,
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _unblocking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('차단 해제 실패: $e')));
    }
  }
}
