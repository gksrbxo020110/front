import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'inspection_worktype_screen.dart'; // WorkTypeGear 사용
import '../detect/inspection_detection_screen.dart';

class InspectionWorkerScreen extends StatefulWidget {
  final WorkTypeGear workType;
  const InspectionWorkerScreen({super.key, required this.workType});

  @override
  State<InspectionWorkerScreen> createState() => _InspectionWorkerScreenState();
}

class _InspectionWorkerScreenState extends State<InspectionWorkerScreen> {
  List<Map<String, dynamic>> workers = [];
  Map<String, dynamic>? selectedWorker;
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    setState(() => isLoading = true);
    try {
      final list = await ApiService.getSiteWorkers();
      if (!mounted) return;
      setState(() {
        workers = list;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('노동자 목록 조회 실패: $e')));
    }
  }

  Future<void> _search(String nickname) async {
    if (nickname.trim().isEmpty) {
      _loadWorkers();
      return;
    }
    setState(() => isLoading = true);
    try {
      final result = await ApiService.searchWorker(nickname: nickname.trim());
      if (!mounted) return;
      setState(() {
        workers = result != null ? [result] : [];
        selectedWorker = null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '노동자 선택',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.workType.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '닉네임으로 검색',
                          border: InputBorder.none,
                        ),
                        onSubmitted: _search,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _search(_searchController.text),
                      child: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : workers.isEmpty
                  ? const Center(
                      child: Text(
                        '등록된 노동자가 없습니다',
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
                        final w = workers[index];
                        final blocked = w['entryBlocked'] == true; // 출입 차단 여부
                        final selected =
                            selectedWorker != null &&
                            selectedWorker!['userId'] == w['userId'];
                        return GestureDetector(
                          // 차단된 노동자는 선택 불가 (안내만)
                          onTap: blocked
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '출입이 제한된 작업자입니다 (안전등급 위험). 관리자가 해제해야 점검할 수 있습니다.',
                                      ),
                                      duration: Duration(milliseconds: 1800),
                                    ),
                                  );
                                }
                              : () => setState(() => selectedWorker = w),
                          behavior: HitTestBehavior.opaque,
                          child: Opacity(
                            // 차단되면 흐리게
                            opacity: blocked ? 0.45 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: blocked
                                    ? const Color(0xFFEEEEEE)
                                    : const Color(0xFFEDE7F6),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${w['name']} · ${w['nickname']}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          blocked
                                              ? '출입 제한됨 (관리자 해제 필요)'
                                              : (w['userId'] ?? ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: blocked
                                                ? AppColors.danger
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 차단 표시 아이콘
                                  if (blocked)
                                    const Icon(
                                      Icons.block,
                                      color: AppColors.danger,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: selectedWorker == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InspectionDetectionScreen(
                              workType: widget.workType.name,
                              userId: selectedWorker!['userId'],
                              worker: selectedWorker!['name'] ?? '',
                              nickname: selectedWorker!['nickname'] ?? '',
                            ),
                          ),
                        );
                      },
                child: const Text('점검 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
