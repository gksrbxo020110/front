import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class WorkerSiteScreen extends StatefulWidget {
  const WorkerSiteScreen({super.key});

  @override
  State<WorkerSiteScreen> createState() => _WorkerSiteScreenState();
}

class _WorkerSiteScreenState extends State<WorkerSiteScreen> {
  final TextEditingController codeController = TextEditingController();

  Map<String, dynamic>? mySite; // 소속 현장 (없으면 null)
  bool isLoading = true; // 처음 조회 중
  bool isJoining = false; // 참여 요청 중

  @override
  void initState() {
    super.initState();
    _loadMySite();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  // 내 현장 조회
  Future<void> _loadMySite() async {
    setState(() => isLoading = true);
    try {
      final site = await ApiService.getMySite();
      if (!mounted) return;
      setState(() => mySite = site);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 조회 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 현장 참여
  Future<void> _joinSite() async {
    final code = codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => isJoining = true);
    try {
      await ApiService.joinSite(siteCode: code);
      if (!mounted) return;
      codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현장에 등록되었습니다'),
          backgroundColor: AppColors.safe,
          duration: Duration(seconds: 1),
        ),
      );
      await _loadMySite(); // 참여 후 다시 조회해서 화면 갱신
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 참여 실패: $e')));
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  // 현장 나가기
  Future<void> _leaveSite() async {
    try {
      await ApiService.leaveSite();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현장에서 탈퇴했습니다'),
          duration: Duration(seconds: 1),
        ),
      );
      await _loadMySite(); // 탈퇴 후 다시 조회
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 나가기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '현장 관리',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 소속 현장 있으면 현장 정보, 없으면 안내 문구
                    if (mySite != null) ...[
                      const Text(
                        '현재 소속 현장',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mySite!['siteName'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '현장 코드: ${mySite!['siteCode'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 탈퇴 버튼
                            GestureDetector(
                              onTap: () => _showLeaveDialog(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.danger),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '탈퇴',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      const Text(
                        '현재 소속 현장',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '소속된 현장이 없습니다.\n아래에 현장 코드를 입력해 등록하세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // 새 현장 등록 (소속 현장 없을 때만 보여줌)
                    if (mySite == null) ...[
                      const Text(
                        '새 현장 등록',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(hintText: '현장 코드 입력'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isJoining ? null : _joinSite,
                        child: isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('현장 등록'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // 현장 탈퇴 확인 팝업
  void _showLeaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, size: 44, color: AppColors.danger),
            const SizedBox(height: 16),
            const Text(
              '현장에서 탈퇴할까요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '탈퇴 시 현장 소속이 해제되며\n관리자에게 탈퇴 알림이 전송됩니다.',
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
                Navigator.pop(context); // 팝업 닫기
                _leaveSite(); // 서버에 탈퇴 요청
              },
              child: const Text('탈퇴'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
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
}
