import 'package:flutter/material.dart';
import 'inspection_detection_screen.dart';
import 'api_service.dart';

class InsWorker {
  final String userId;
  final String name;
  final String nickname;
  final bool entryBlocked; // 출입 차단 (RED 3회) → 선택 불가
  const InsWorker(this.userId, this.name, this.nickname, this.entryBlocked);
}

class InspectionWorkerScreen extends StatefulWidget {
  final String workType;
  const InspectionWorkerScreen({super.key, required this.workType});

  @override
  State<InspectionWorkerScreen> createState() => _InspectionWorkerScreenState();
}

class _InspectionWorkerScreenState extends State<InspectionWorkerScreen> {
  final searchController = TextEditingController();
  int selected = -1;
  String keyword = '';

  bool loading = true;
  List<InsWorker> workers = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    setState(() => loading = true);
    List<Map<String, dynamic>> list = [];
    try {
      list = await ApiService.getSiteWorkerList();
    } catch (e) {
      debugPrint('노동자 목록 불러오기 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      workers = list
          .map(
            (w) => InsWorker(
              w['userId']?.toString() ?? '',
              w['name']?.toString() ?? '',
              w['nickname']?.toString() ?? '',
              w['entryBlocked'] == true,
            ),
          )
          .toList();
      selected = -1; // 목록 새로 받으면 선택 초기화
      loading = false;
    });
  }

  List<InsWorker> get filtered {
    if (keyword.trim().isEmpty) return workers;
    final k = keyword.trim();
    return workers
        .where((w) => w.name.contains(k) || w.nickname.contains(k))
        .toList();
  }

  // 차단된 노동자를 눌렀을 때 안내
  void _showBlockedNotice(InsWorker w) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${w.name}님은 출입이 제한된 노동자예요 · 관리자 대시보드에서 해제할 수 있어요'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 점검 시작 → 13번 감지 화면 (돌아오면 목록 새로고침: 방금 점검으로 차단됐을 수 있음)
  Future<void> _startInspection(InsWorker w) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionDetectionScreen(
          worker: w.name,
          nickname: w.nickname,
          userId: w.userId,
          workType: widget.workType,
        ),
      ),
    );
    if (mounted) _loadWorkers();
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
                    '노동자 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  widget.workType,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 검색창
              TextField(
                controller: searchController,
                onChanged: (v) => setState(() {
                  keyword = v;
                  selected = -1; // 검색어 바뀌면 선택 초기화
                }),
                decoration: InputDecoration(
                  hintText: '닉네임으로 검색',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 14,
                  ),
                  suffixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9A9A9A),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF6F5FC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF7F77DD)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 노동자 목록
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7F77DD),
                        ),
                      )
                    : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_off,
                              size: 48,
                              color: Color(0xFFB0B0B0),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              keyword.trim().isEmpty
                                  ? '현장에 등록된 노동자가 없습니다.'
                                  : '검색 결과가 없습니다.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF7F77DD),
                        onRefresh: _loadWorkers,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: list.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final w = list[i];
                            final bool blocked = w.entryBlocked;
                            final bool isSel = !blocked && selected == i;
                            return GestureDetector(
                              onTap: () {
                                if (blocked) {
                                  _showBlockedNotice(w);
                                  return;
                                }
                                setState(() => selected = i);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: blocked
                                      ? const Color(0xFFF2F2F2)
                                      : const Color(0xFFF6F5FC),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF7F77DD)
                                        : blocked
                                        ? const Color(0xFFE0E0E0)
                                        : const Color(0xFFE0DEF5),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: blocked
                                            ? const Color(0xFFE0E0E0)
                                            : const Color(0xFFE0DEF5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: blocked
                                            ? const Color(0xFFB0B0B0)
                                            : const Color(0xFF7F77DD),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: blocked
                                                  ? const Color(0xFFB0B0B0)
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${w.nickname}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFB0B0B0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (blocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDECEC),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock,
                                              size: 12,
                                              color: Color(0xFFE24B4A),
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              '출입 제한',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFE24B4A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isSel)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF7F77DD),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // 점검 시작 버튼 → 13번 감지 화면
              GestureDetector(
                onTap: selected == -1 || selected >= list.length
                    ? null
                    : () => _startInspection(list[selected]),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selected == -1
                        ? const Color(0xFFE0E0E0)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '점검 시작',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected == -1
                          ? const Color(0xFF9A9A9A)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
