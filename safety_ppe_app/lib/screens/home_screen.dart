import 'package:flutter/material.dart';
import 'site_manage_screen.dart';
import 'inspection_work_screen.dart';
import 'gate_qr_screen.dart';
import 'api_service.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  bool loading = true;
  dynamic siteId; // 소속 현장 id (없으면 null)
  String siteName = '';
  int greenCount = 0;
  int yellowCount = 0;
  int redCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final result = await ApiService.getManagerDashboard();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        siteId = result['siteId'];
        siteName = result['siteName']?.toString() ?? '';
        greenCount = result['greenCount'] ?? 0;
        yellowCount = result['yellowCount'] ?? 0;
        redCount = result['redCount'] ?? 0;
        loading = false;
      });
    } else {
      // 대시보드 실패(현장 없음 등) → 내 정보로 소속 현장 한 번 더 확인
      dynamic id;
      String name = '';
      try {
        final info = await ApiService.getMyInfo();
        if (info['success'] == true) {
          id = info['siteId'];
          name = info['siteName']?.toString() ?? '';
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        siteId = id;
        siteName = name;
        greenCount = 0;
        yellowCount = 0;
        redCount = 0;
        loading = false;
      });
    }
  }

  // 소속 현장이 있는지 (현장 없으면 Gate·Inspection 막음)
  bool get _hasSite => siteId != null || siteName.isNotEmpty;

  // Gate·Inspection 진입 (현장 없으면 안내만)
  void _openMode(Widget screen) {
    if (loading) return; // 아직 현장 정보 불러오는 중
    if (!_hasSite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('소속 현장이 없어요 · 현장 관리에서 현장을 먼저 생성해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _openAndRefresh(screen);
  }

  // 다른 화면 갔다가 돌아오면 숫자 새로고침
  void _openAndRefresh(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _load());
  }

  // 불러오는 동안엔 0 대신 '-' 표시 (0 → 실제 숫자 깜빡임 방지)
  String _countText(int n) => loading ? '-' : '$n';

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
                const SizedBox(height: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안녕하세요, 관리자님',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI 스마트 안전 메이트',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 현장명 (서버 연동)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Color(0xFF7F77DD),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loading
                              ? '불러오는 중...'
                              : (siteName.isEmpty ? '소속 현장 없음' : siteName),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 현장 안전 등급 현황 (등급별 노동자 수, 서버 연동)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '현장 안전 등급 현황',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _GradeStat(
                            count: _countText(greenCount),
                            label: '그린',
                            color: const Color(0xFF639922),
                          ),
                          _GradeStat(
                            count: _countText(yellowCount),
                            label: '옐로',
                            color: const Color(0xFFBA7517),
                          ),
                          _GradeStat(
                            count: _countText(redCount),
                            label: '레드',
                            color: const Color(0xFFE24B4A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '감지 모드 선택',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
                const SizedBox(height: 10),

                // ── Gate 카드 (9번 연결) ──
                GestureDetector(
                  onTap: () => _openMode(const GateQrScreen()),
                  child: _ModeCard(
                    icon: Icons.qr_code_scanner,
                    title: 'Gate 모드',
                    subtitle: 'QR 스캔 · 무인 입장 체크',
                    filled: true,
                    disabled: !loading && !_hasSite,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Inspection 카드 (11번 연결) ──
                GestureDetector(
                  onTap: () => _openMode(const InspectionWorkScreen()),
                  child: _ModeCard(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Inspection 모드',
                    subtitle: '관리자 순찰 점검자',
                    filled: false,
                    disabled: !loading && !_hasSite,
                  ),
                ),
                if (!loading && !_hasSite) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '소속 현장이 없으면 Gate·Inspection 모드를 사용할 수 없어요',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE24B4A)),
                  ),
                ],
                const SizedBox(height: 22),

                // ── 현장 관리 버튼 ──
                GestureDetector(
                  onTap: () => _openAndRefresh(const SiteManageScreen()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '현장 관리',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
        ),
      ),
    );
  }
}

class _GradeStat extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _GradeStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final bool disabled; // 현장 없음 → 흐리게
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final Color fg = filled ? Colors.white : const Color(0xFF1A1A1A);
    final Color sub = filled
        ? const Color(0xFFB8B8B8)
        : const Color(0xFF9A9A9A);

    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: filled
            ? null
            : Border.all(color: const Color(0xFFE5E5E5), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: fg),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right,
            color: filled ? const Color(0xFF6B6B6B) : const Color(0xFFC4C4C4),
          ),
        ],
      ),
      ),
    );
  }
}
