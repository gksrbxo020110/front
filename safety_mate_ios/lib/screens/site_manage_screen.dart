import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'site_create_screen.dart';

class SiteManageScreen extends StatefulWidget {
  const SiteManageScreen({super.key});

  @override
  State<SiteManageScreen> createState() => _SiteManageScreenState();
}

class _SiteManageScreenState extends State<SiteManageScreen> {
  Map<String, dynamic>? mySite; // 내 현장 (없으면 null)
  int? workerCount; // 노동자 수 (현장 있을 때만)
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMySite();
  }

  // 내 현장 + 노동자 수 조회
  Future<void> _loadMySite() async {
    setState(() => isLoading = true);
    try {
      final site = await ApiService.getMySite();
      int? count;
      // 현장이 있으면 노동자 수도 조회
      if (site != null) {
        try {
          count = await ApiService.getWorkerCount();
        } catch (_) {
          count = null; // 노동자 수 조회 실패해도 현장은 보여줌
        }
      }
      if (!mounted) return;
      setState(() {
        mySite = site;
        workerCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 조회 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 현장 삭제
  Future<void> _deleteSite() async {
    try {
      await ApiService.deleteSite();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현장이 삭제되었습니다'),
          duration: Duration(seconds: 1),
        ),
      );
      await _loadMySite(); // 삭제 후 다시 조회
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 삭제 실패: $e')));
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 4),
              const Text(
                '현장을 만들면 코드가 생성됩니다. 노동자가 이 코드로 현장에 등록됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // 로딩 / 현장 있음 / 현장 없음 분기
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (mySite == null ? _emptyView() : _siteView()),
              ),

              // 현장 없을 때만 생성 버튼 (관리자는 현장 하나만)
              if (!isLoading && mySite == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SiteCreateScreen(),
                        ),
                      );
                      await _loadMySite();
                    },
                    child: const Text('현장 등록/생성'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 빈 상태 화면
  Widget _emptyView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.holiday_village_outlined,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 16),
        const Text(
          '등록된 현장이 없습니다',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          '첫 현장을 만들고\n노동자에게 코드를 전달하세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // 현장 있을 때 화면 (단일 현장)
  Widget _siteView() {
    // 노동자 수 문구 (조회 성공하면 "노동자 N명", 실패/없으면 주소만)
    final countText = workerCount != null ? '노동자 $workerCount명' : null;

    return ListView(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5), // 연보라
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        // 노동자 수 (있으면)
                        if (countText != null)
                          Text(
                            countText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        if (countText != null) const SizedBox(height: 2),
                        // 주소
                        Text(
                          mySite!['address'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 점 3개 메뉴 → 삭제
                  GestureDetector(
                    onTap: () => _showDeleteMenu(),
                    child: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 코드 + 복사/공유
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mySite!['siteCode'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('현장 코드가 복사되었습니다'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.link,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('공유하기'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.share,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 점 3개 누르면 하단에서 올라오는 삭제 메뉴
  void _showDeleteMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                mySite!['siteName'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                '현장 삭제',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(context); // 메뉴 닫고
                _showDeleteConfirm(); // 삭제 확인 팝업
              },
            ),
          ],
        ),
      ),
    );
  }

  // 삭제 확인 팝업
  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            const Text(
              '현장을 삭제할까요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${mySite!['siteName'] ?? ''}\n소속 노동자가 없어야 삭제할 수 있으며\n되돌릴 수 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                Navigator.pop(context); // 팝업 닫고
                _deleteSite(); // 서버에 삭제 요청
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
