import 'package:flutter/material.dart';
import 'detection_result_screen.dart';
import 'api_service.dart';

class WorkerNotificationScreen extends StatefulWidget {
  final bool isTab; // 탭으로 열림=뒤로가기 없음
  const WorkerNotificationScreen({super.key, this.isTab = false});

  @override
  State<WorkerNotificationScreen> createState() =>
      _WorkerNotificationScreenState();
}

class _WorkerNotificationScreenState extends State<WorkerNotificationScreen> {
  bool loading = true;
  bool _opening = false; // 결과 화면 여는 중 (기록 찾는 중)
  List<Map<String, dynamic>> notis = [];

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
      notis = list;
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

  // 알림 카드 탭 → 읽음 처리 → 감지 결과 화면(14번)
  Future<void> _onTapNoti(Map<String, dynamic> noti) async {
    if (_opening) return;

    // 1) 안 읽은 알림이면 읽음 처리
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

    // 3) 본인 대시보드 이력에서 찾기
    if (!mounted) return;
    setState(() => _opening = true);

    Map<String, dynamic>? found;
    String myName = '';
    try {
      final res = await ApiService.getWorkerDashboard();
      if (res['success'] == true) {
        myName = res['name']?.toString() ?? '';
        final List history = res['history'] ?? [];
        for (final h in history) {
          if (h['recordId']?.toString() == recordId) {
            found = Map<String, dynamic>.from(h);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('감지 기록 찾기 실패: $e');
    }

    if (!mounted) return;
    setState(() => _opening = false);

    if (found == null) {
      _snack('감지 기록을 찾을 수 없어요');
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetectionResultScreen.fromRecord(found!, workerName: myName),
        ),
      );
    }

    // 돌아오면 목록 갱신 (빨강 → 흰색)
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
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
                        '알림',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF7F77DD),
                            ),
                          )
                        : notis.isEmpty
                        ? const Center(
                            child: Text(
                              '알림이 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: notis.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _notiCard(notis[i]),
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

  Widget _notiCard(Map<String, dynamic> noti) {
    final bool unread = noti['isRead'] != true; // 안 읽은 알림 = 빨강 강조
    final String message = noti['message']?.toString() ?? '알림';
    final String time = _formatTime(noti['sentAt']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _onTapNoti(noti),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFE24B4A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: unread ? null : Border.all(color: const Color(0xFFE5E5E5)),
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
                  color: unread ? Colors.white : const Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: unread ? Colors.white : const Color(0xFF1A1A1A),
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
                color: unread ? Colors.white60 : const Color(0xFF9A9A9A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
