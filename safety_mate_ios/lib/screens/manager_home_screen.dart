import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'gate_scan_screen.dart';
import 'inspection_worktype_screen.dart';
import 'site_manage_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  String _siteName = '소속 현장 없음';
  bool _hasSite = false; // 소속 현장 보유 여부
  int _green = 0;
  int _yellow = 0;
  int _red = 0;
  int _todayViolation = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final dash = await ApiService.getManagerDashboard();
      if (!mounted) return;
      setState(() {
        _siteName = dash['siteName'] ?? '소속 현장 없음';
        _hasSite = dash['siteName'] != null && dash['siteName'] != '';
        _green = dash['greenCount'] ?? 0;
        _yellow = dash['yellowCount'] ?? 0;
        _red = dash['redCount'] ?? 0;
        _todayViolation = dash['todayViolationCount'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // 소속 현장 없으면 모드 진입 막고 안내
  bool _checkSite() {
    if (!_hasSite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('소속된 현장이 없습니다 · 현장 관리에서 먼저 현장을 생성하거나 참여해주세요'),
          duration: Duration(milliseconds: 2000),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'AI 스마트 안전 메이트',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // 현재 현장 (서버)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '현재 현장',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _siteName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 오늘 현황 (서버 컬러링 + 오늘 미착용)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '컬러링 현황',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '오늘 미착용 $_todayViolation건',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _colorCount('$_green', '그린', AppColors.safe),
                                _colorCount(
                                  '$_yellow',
                                  '옐로',
                                  AppColors.warning,
                                ),
                                _colorCount('$_red', '레드', AppColors.danger),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 감지 모드 선택
                      const Text(
                        '감지 모드',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _modeCard(
                        icon: Icons.sensor_door_outlined,
                        title: 'Gate 모드',
                        desc: '무인 자동 입장 · QR 스캔 후 감지',
                        onTap: () {
                          if (!_checkSite()) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GateScanScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _modeCard(
                        icon: Icons.fact_check_outlined,
                        title: 'Inspection 모드',
                        desc: '관리자 순찰 · 작업 종류별 점검',
                        onTap: () {
                          if (!_checkSite()) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InspectionWorktypeScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 현장 관리 버튼
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('현장 관리'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SiteManageScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _colorCount(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
