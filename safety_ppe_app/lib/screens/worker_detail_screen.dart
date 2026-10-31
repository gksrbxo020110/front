import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detection_result_screen.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String userId; // 조회 대상 노동자 userId
  final String name;
  final String nick;
  final String grade; // 한글: 레드/옐로/그린 (초기 표시용)
  final int count; // 초기 표시용
  final Color color;
  const WorkerDetailScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.nick,
    required this.grade,
    required this.count,
    required this.color,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  bool _loading = true;
  bool _unassigning = false;
  bool _unblocking = false;

  String _grade = '그린';
  int _count = 0;
  List<Map<String, dynamic>> _history = []; // 미착용 이력 (착용 완료 기록 제외)

  // 출입 차단 여부 (null = 모름/불러오기 실패)
  // 서버 상세 응답엔 차단 값이 없어서 노동자 목록(GET /api/sites/workers)의 entryBlocked 사용
  bool? _blocked;

  bool get isRed => _grade == '레드';

  @override
  void initState() {
    super.initState();
    // 목록에서 넘어온 값으로 우선 표시(깜빡임 방지)
    _grade = widget.grade;
    _count = widget.count;
    _load();
  }

  String _gradeKo(String? g) {
    switch (g) {
      case 'RED':
        return '레드';
      case 'YELLOW':
        return '옐로';
      case 'GREEN':
      default:
        return '그린';
    }
  }

  // 미착용 항목이 하나라도 있는 기록인지
  // (iOS가 저장한 '착용 완료' 기록은 notWornItems가 비어 있음 → 이력에서 제외)
  bool _hasNotWorn(Map<String, dynamic> h) {
    final items = h['notWornItems'];
    if (items is! List) return false;
    return items.any((e) => e.toString().trim().isNotEmpty);
  }

  // 노동자 목록에서 이 노동자의 차단 여부 찾기
  Future<bool?> _loadBlocked() async {
    try {
      final list = await ApiService.getSiteWorkerList();
      for (final w in list) {
        if (w['userId']?.toString() == widget.userId) {
          return w['entryBlocked'] == true;
        }
      }
    } catch (e) {
      debugPrint('출입 차단 여부 불러오기 실패: $e');
    }
    return null;
  }

  Future<void> _load() async {
    // 상세 + 차단 여부를 동시에
    final results = await Future.wait([
      ApiService.getWorkerDashboardById(widget.userId),
      _loadBlocked(),
    ]);
    if (!mounted) return;

    final res = results[0] as Map<String, dynamic>;
    final blocked = results[1] as bool?;

    if (res['success'] == true) {
      final List rawHistory = res['history'] ?? [];
      final history = rawHistory
          .map<Map<String, dynamic>>((h) => Map<String, dynamic>.from(h))
          .where(_hasNotWorn) // 착용 완료 기록 제외 → 누적 건수와 이력 개수 일치
          .toList();

      setState(() {
        _grade = _gradeKo(res['grade']?.toString());
        _count = res['violationCount'] ?? 0;
        _history = history;
        _blocked = blocked;
        _loading = false;
      });
    } else {
      setState(() {
        _blocked = blocked;
        _loading = false;
      });
    }
  }

  // ── 출입 차단 해제 확인 팝업 ──
  void _showUnblockDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDEBF9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_open,
                  color: Color(0xFF534AB7),
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '출입 차단을 해제할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: widget.name,
                      style: const TextStyle(
                        color: Color(0xFF534AB7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '님의 게이트 출입과 점검이 다시 가능해집니다.\n등급(레드)과 누적 건수는 그대로이며\n미착용이 다시 감지되면 자동으로 차단됩니다.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _doUnblock();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF534AB7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '차단 해제',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 출입 차단 해제 API 호출 ──
  Future<void> _doUnblock() async {
    if (_unblocking) return;
    setState(() => _unblocking = true);
    Map<String, dynamic> res;
    try {
      res = await ApiService.unblockWorker(widget.userId);
    } catch (e) {
      res = {'success': false, 'body': '서버에 연결할 수 없어요'};
    }
    if (!mounted) return;
    setState(() => _unblocking = false);

    if (res['success'] == true) {
      setState(() => _blocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('출입 차단이 해제되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('해제 실패: ${res['body']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 소속 해제 확인 팝업
  void _showUnassignDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_off,
                  color: Color(0xFFE24B4A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '소속을 해제할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: widget.name,
                      style: const TextStyle(
                        color: Color(0xFFE24B4A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '님을 현장에서 소속 해제합니다.\nQR 코드가 즉시 무효화되며\n되돌릴 수 없습니다.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _unassigning ? null : _doUnassign,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _unassigning ? '처리 중...' : '소속 해제',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 실제 소속 해제 API 호출
  Future<void> _doUnassign() async {
    setState(() => _unassigning = true);
    final res = await ApiService.removeWorker(widget.userId);
    if (!mounted) return;
    setState(() => _unassigning = false);

    Navigator.pop(context); // 팝업 닫기
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('소속 해제되었습니다'),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pop(context); // 상세 화면 닫고 목록으로
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('해제 실패: ${res['body']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 날짜 문자열 파싱 ("2026-07-08T09:41:00" → "2026.07.08 09:41")
  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}.${two(dt.month)}.${two(dt.day)} '
          '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  // ── 출입 상태 카드 (차단 중 / 레드인데 해제됨) ──
  Widget _buildEntryCard() {
    // 차단 중 → 안내 + 해제 버튼
    if (_blocked == true) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBEB),
          border: Border.all(color: const Color(0xFFF3C4C4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock, size: 18, color: Color(0xFFE24B4A)),
                SizedBox(width: 6),
                Text(
                  '출입 제한 중',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE24B4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '미착용 누적으로 게이트 출입과 점검이 제한된 상태예요',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _unblocking ? null : _showUnblockDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _unblocking
                      ? const Color(0xFF9A9A9A)
                      : const Color(0xFF534AB7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_open, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _unblocking ? '처리 중...' : '출입 차단 해제',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 레드인데 차단은 풀린 상태 → 안내만
    if (_blocked == false && isRed) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F5FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_open, size: 16, color: Color(0xFF534AB7)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '출입 가능 (해제됨) · 미착용이 다시 감지되면 자동으로 차단돼요',
                style: TextStyle(fontSize: 12, color: Color(0xFF534AB7)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 앱바
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.chevron_left, size: 26),
                      ),
                    ),
                    const Text(
                      '노동자 상세',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 프로필 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRed
                        ? const Color(0xFFE24B4A)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isRed
                              ? Colors.white.withValues(alpha: 0.25)
                              : widget.color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isRed
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (widget.nick.isNotEmpty)
                                  Text(
                                    ' · ${widget.nick}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isRed
                                          ? Colors.white70
                                          : const Color(0xFF9A9A9A),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_grade${isRed ? " (위험)" : ""} · 누적 미착용 $_count건',
                              style: TextStyle(
                                fontSize: 12,
                                color: isRed
                                    ? Colors.white
                                    : const Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 출입 상태 (차단 중 → 해제 버튼 / 레드인데 해제됨 → 안내)
                _buildEntryCard(),
                const SizedBox(height: 22),

                // 미착용 이력 · 캡처사진
                const Text(
                  '미착용 이력 · 캡처사진',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '사진을 탭하면 미착용 항목이 표시됩니다',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 12),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7F77DD),
                      ),
                    ),
                  )
                else if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '미착용 이력이 없습니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                    ),
                  )
                else
                  ..._history.map((h) {
                    final mode = h['detectionMode']?.toString() ?? '';
                    final workType = h['workType']?.toString() ?? '';
                    final modeLabel = mode == 'GATE'
                        ? 'Gate · 공통보호구'
                        : 'Inspection${workType.isNotEmpty ? " · $workType" : ""}';
                    final List notWorn = h['notWornItems'] ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CaptureItem(
                        worker: widget.name,
                        record: h, // ★ 기록 전체 → 결과 화면에서 사진·체크리스트 표시
                        summary:
                            h['summary']?.toString() ??
                            (notWorn.isNotEmpty
                                ? '${notWorn.first} 미착용'
                                : '미착용'),
                        mode: modeLabel,
                        time: _fmtTime(h['detectedAt']?.toString()),
                        s3Key: h['s3Key']?.toString(),
                      ),
                    );
                  }),
                const SizedBox(height: 14),

                // 현장에서 소속 해제 버튼
                GestureDetector(
                  onTap: _showUnassignDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      border: Border.all(color: const Color(0xFFE24B4A)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 18,
                          color: Color(0xFFE24B4A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '현장에서 소속 해제',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE24B4A),
                          ),
                        ),
                      ],
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

class _CaptureItem extends StatelessWidget {
  final String worker;
  final Map<String, dynamic> record; // 감지 기록 전체
  final String summary;
  final String mode;
  final String time;
  final String? s3Key;
  const _CaptureItem({
    required this.worker,
    required this.record,
    required this.summary,
    required this.mode,
    required this.time,
    required this.s3Key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 기록 전체를 넘겨서 결과 화면(14번)에서 사진 + 착용/미착용 체크리스트 표시
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetectionResultScreen.fromRecord(record, workerName: worker),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F5FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 캡처 썸네일 (s3Key → view-url)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _Thumb(s3Key: s3Key),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB0B0B0),
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

// 캡처 썸네일 (s3Key로 view-url 받아 로딩)
class _Thumb extends StatelessWidget {
  final String? s3Key;
  const _Thumb({required this.s3Key});

  @override
  Widget build(BuildContext context) {
    const double size = 56;
    if (s3Key == null || s3Key!.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.image, color: Color(0xFF5A5A5A), size: 26),
      );
    }
    return FutureBuilder<String?>(
      future: ApiService.getS3ViewUrl(s3Key!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white30,
                ),
              ),
            ),
          );
        }
        final url = snap.data;
        if (url == null || url.isEmpty) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFF1A1A1A),
            child: const Icon(
              Icons.broken_image,
              color: Color(0xFF5A5A5A),
              size: 24,
            ),
          );
        }
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: const Color(0xFF1A1A1A),
            child: const Icon(
              Icons.broken_image,
              color: Color(0xFF5A5A5A),
              size: 24,
            ),
          ),
        );
      },
    );
  }
}
