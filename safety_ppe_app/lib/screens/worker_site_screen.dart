import 'package:flutter/material.dart';
import 'api_service.dart';

class WorkerSiteScreen extends StatefulWidget {
  const WorkerSiteScreen({super.key});

  @override
  State<WorkerSiteScreen> createState() => _WorkerSiteScreenState();
}

class _WorkerSiteScreenState extends State<WorkerSiteScreen> {
  final codeController = TextEditingController();
  bool loading = true;
  bool hasSite = false;
  String siteName = '';
  String siteCode = '';
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMySite();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 내 현장 조회
  Future<void> _loadMySite() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.getMySite();
      if (result['success'] == true && result['siteCode'] != null) {
        setState(() {
          hasSite = true;
          siteName = result['siteName'] ?? '';
          siteCode = result['siteCode'] ?? '';
        });
      } else {
        setState(() => hasSite = false);
      }
    } catch (e) {
      setState(() => hasSite = false);
    } finally {
      setState(() => loading = false);
    }
  }

  // 현장 등록 (참여)
  Future<void> _register() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      _snack('현장 코드를 입력해주세요');
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await ApiService.joinSite(code);
      if (result['success'] == true) {
        _snack('현장에 등록되었습니다');
        codeController.clear();
        await _loadMySite();
      } else {
        _snack('등록 실패: 현장 코드를 확인해주세요');
      }
    } catch (e) {
      _snack('서버 연결 실패: $e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  // 현장 탈퇴
  Future<void> _leaveSite() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.leaveSite();
      if (result['success'] == true) {
        _snack('현장에서 탈퇴했습니다');
        setState(() {
          hasSite = false;
          siteName = '';
          siteCode = '';
        });
        await _loadMySite();
      } else {
        _snack('탈퇴 실패: ${result['body']}');
        setState(() => loading = false);
      }
    } catch (e) {
      _snack('서버 연결 실패: $e');
      setState(() => loading = false);
    }
  }

  // 탈퇴 확인 팝업
  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, color: Color(0xFFE24B4A), size: 30),
              const SizedBox(height: 12),
              const Text(
                '현장에서 탈퇴할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '$siteName\n소속이 해제됩니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6B6B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _leaveSite();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '탈퇴',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
                  ),
                  const Text(
                    '현장 관리',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasSite)
                // ── 소속 현장 있음: 카드만 (등록 섹션 숨김) ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '현재 소속 현장',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B6B6B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    siteName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '현장 코드 : ${siteCode.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _showLeaveDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '탈퇴',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF8A8A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                // ── 소속 현장 없음: 등록 섹션만 ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '소속된 현장이 없습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '새 현장 등록',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          hintText: '현장 코드 입력',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF6FA8F5),
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: submitting ? null : _register,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: submitting
                                ? const Color(0xFFCCCCCC)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            submitting ? '등록 중...' : '현장 등록',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
