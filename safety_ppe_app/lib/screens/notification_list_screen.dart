import 'package:flutter/material.dart';
import 'detection_result_screen.dart';
import 'api_service.dart';

// ★ 오늘/어제 분류 버튼 표시 (임시로 숨김)
// 서버 시간대가 UTC라 오전 9시 이전 알림이 하루 밀려 분류될 수 있음
// → 서버가 Asia/Seoul로 바뀌면 true로 바꾸면 바로 다시 보임 (분류 코드는 그대로 있음)
const bool showDateFilter = false;

// 찾은 감지 기록 + 노동자 이름
class _FoundRecord {
  final Map<String, dynamic> record;
  final String workerName;
  const _FoundRecord(this.record, this.workerName);
}

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  int filterIndex = 0; // 0=전체, 1=오늘, 2=어제 (showDateFilter=false면 항상 전체)
  bool loading = true;
  bool _opening = false; // 결과 화면 여는 중 (기록 찾는 중)
  List<Map<String, dynamic>> allNotis = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final list = await ApiService.getMyNotifications();
    if (!mounted) return;
    setState(() {
      allNotis = list;
      loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 시간 포맷 (2026-07-08T14:20 → 2026.07.08 14:20)
  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      final yyyy = d.year;
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '$yyyy.$mm.$dd $hh:$mi';
    } catch (e) {
      return raw;
    }
  }

  // 오늘/어제 판별
  bool _isToday(String raw) {
    try {
      final d = DateTime.parse(raw);
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    } catch (e) {
      return false;
    }
  }

  bool _isYesterday(String raw) {
    try {
      final d = DateTime.parse(raw);
      final y = DateTime.now().subtract(const Duration(days: 1));
      return d.year == y.year && d.month == y.month && d.day == y.day;
    } catch (e) {
      return false;
    }
  }

  // 필터 적용된 목록 (분류 버튼을 숨겼으면 항상 전체)
  List<Map<String, dynamic>> get filtered {
    if (!showDateFilter) return allNotis;
    if (filterIndex == 1) {
      return allNotis
          .where((n) => _isToday(n['sentAt']?.toString() ?? ''))
          .toList();
    }
    if (filterIndex == 2) {
      return allNotis
          .where((n) => _isYesterday(n['sentAt']?.toString() ?? ''))
          .toList();
    }
    return allNotis;
  }

  // ── recordId로 감지 기록 찾기 (관리자) ──
  // 기록 1건 조회 API가 없어서, 현장 노동자들의 대시보드 이력을 차례로 확인
  // TODO: 팀장님이 GET /api/detections/{recordId} 만들면 이 함수만 교체
  Future<_FoundRecord?> _findRecord(String recordId) async {
    try {
      final dash = await ApiService.getManagerDashboard();
      if (dash['success'] != true) return null;

      // 미착용 많은 노동자부터 확인 (알림은 보통 미착용 때 오니까)
      final List rawWorkers = dash['workers'] ?? [];
      final workers = rawWorkers
          .map<Map<String, dynamic>>((w) => Map<String, dynamic>.from(w))
          .toList();
      workers.sort((a, b) {
        final int ca = (a['violationCount'] is int) ? a['violationCount'] : 0;
        final int cb = (b['violationCount'] is int) ? b['violationCount'] : 0;
        return cb.compareTo(ca);
      });

      for (final w in workers) {
        final uid = w['userId']?.toString() ?? '';
        if (uid.isEmpty) continue;

        final res = await ApiService.getWorkerDashboardById(uid);
        if (res['success'] != true) continue;

        final List history = res['history'] ?? [];
        for (final h in history) {
          if (h['recordId']?.toString() == recordId) {
            final name = w['name']?.toString() ?? res['name']?.toString() ?? '';
            return _FoundRecord(Map<String, dynamic>.from(h), name);
          }
        }
      }
    } catch (e) {
      debugPrint('감지 기록 찾기 실패: $e');
    }
    return null;
  }

  // 알림 카드 탭 → 읽음 처리 → 감지 결과 화면(14번)
  Future<void> _onTapNoti(Map<String, dynamic> noti) async {
    if (_opening) return;

    // 1) 읽음 처리
    final id = noti['notificationId'];
    final bool isRead = noti['isRead'] == true;
    if (!isRead && id != null) {
      await ApiService.markNotificationAsRead(
        id is int ? id : int.tryParse(id.toString()) ?? 0,
      );
    }

    // 2) 연결된 감지 기록 확인
    final recordId = noti['recordId']?.toString() ?? '';
    if (recordId.isEmpty || recordId == 'null') {
      _snack('연결된 감지 기록이 없어요');
      await _load();
      return;
    }

    // 3) 기록 찾기
    if (!mounted) return;
    setState(() => _opening = true);
    final found = await _findRecord(recordId);
    if (!mounted) return;
    setState(() => _opening = false);

    if (found == null) {
      _snack('감지 기록을 찾을 수 없어요');
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetectionResultScreen.fromRecord(
            found.record,
            workerName: found.workerName,
          ),
        ),
      );
    }

    // 돌아오면 읽음 상태 갱신
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '알림',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 오늘/어제 분류 버튼 (showDateFilter=false면 숨김)
                  if (showDateFilter) ...[
                    Row(
                      children: [
                        _FilterChip(
                          label: '전체',
                          selected: filterIndex == 0,
                          onTap: () => setState(() => filterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '오늘',
                          selected: filterIndex == 1,
                          onTap: () => setState(() => filterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '어제',
                          selected: filterIndex == 2,
                          onTap: () => setState(() => filterIndex = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF7F77DD),
                            ),
                          )
                        : list.isEmpty
                        ? const Center(
                            child: Text(
                              '알림이 없습니다',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final noti = list[i];
                              final bool unread = noti['isRead'] != true;
                              return _NotiCard(
                                message: noti['message']?.toString() ?? '알림',
                                time: _formatTime(
                                  noti['sentAt']?.toString() ?? '',
                                ),
                                highlight: unread,
                                onTap: () => _onTapNoti(noti),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // ── 기록 찾는 중 오버레이 ──
            if (_opening)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF1EFE8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B6B6B),
          ),
        ),
      ),
    );
  }
}

class _NotiCard extends StatelessWidget {
  final String message;
  final String time;
  final bool highlight;
  final VoidCallback onTap;
  const _NotiCard({
    required this.message,
    required this.time,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFE24B4A) : Colors.white,
          border: highlight ? null : Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: highlight ? Colors.white : const Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: highlight ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: highlight ? Colors.white70 : const Color(0xFFB0B0B0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
