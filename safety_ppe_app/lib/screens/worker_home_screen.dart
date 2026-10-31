import 'package:flutter/material.dart';
import 'worker_qr_screen.dart';
import 'worker_site_screen.dart';
import 'worker_notification_screen.dart';
import 'worker_status_screen.dart';
import 'api_service.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  bool loading = true;
  String name = '';
  String siteName = '';
  String grade = 'GREEN';
  String recentNoti = ''; // 최근 알림 메시지
  String recentNotiTime = ''; // 최근 알림 시간

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      // 내 정보 (이름·현장)
      final info = await ApiService.getMyInfo();
      if (info['success'] == true) {
        name = info['name'] ?? '';
        siteName = info['siteName'] ?? '';
      }
      // 안전 등급
      final dash = await ApiService.getWorkerDashboard();
      if (dash['success'] == true) {
        grade = dash['grade']?.toString() ?? 'GREEN';
      }
      // 최근 알림 1건
      final notis = await ApiService.getMyNotifications();
      if (notis.isNotEmpty) {
        recentNoti = notis[0]['message']?.toString() ?? '';
        recentNotiTime = _formatTime(notis[0]['sentAt']?.toString() ?? '');
      }
    } catch (e) {
      // 무시하고 화면은 뜨게
    } finally {
      setState(() => loading = false);
    }
  }

  // 시간 포맷 (2026-07-08T14:20 → 07.08 14:20)
  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '$mm.$dd $hh:$mi';
    } catch (e) {
      return raw;
    }
  }

  // 등급 한글 + (양호/주의/위험)
  String get _gradeText {
    switch (grade) {
      case 'RED':
        return '레드 (위험)';
      case 'YELLOW':
        return '옐로 (주의)';
      case 'GREEN':
      default:
        return '그린 (양호)';
    }
  }

  // 등급 카드 배경색
  Color get _gradeCardColor {
    switch (grade) {
      case 'RED':
        return const Color(0xFFE24B4A);
      case 'YELLOW':
        return const Color(0xFFBA7517);
      case 'GREEN':
      default:
        return const Color(0xFF3B7D3F);
    }
  }

  // 등급 점 색상 (카드 안, 밝은 색)
  Color get _gradeDotColor {
    switch (grade) {
      case 'RED':
        return const Color(0xFFFFB3B3);
      case 'YELLOW':
        return const Color(0xFFFFD98A);
      case 'GREEN':
      default:
        return const Color(0xFF7BE07B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        '안녕하세요, ${name.isEmpty ? '노동자' : name}님',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        siteName.isEmpty ? '소속 현장 없음' : siteName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── 내 QR 코드 카드 → 20번 ──
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkerQrScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEDED),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.qr_code_2,
                                size: 48,
                                color: Color(0xFF1A1A1A),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '내 QR 코드',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '탭하여 입장 QR 표시',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B6B6B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── 현재 안전 등급 카드 (등급별 색) → 24번 ──
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkerStatusScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _gradeCardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '현재 안전 등급',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 12,
                                        color: _gradeDotColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _gradeText,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── 최근 알림 카드 → 23번 ──
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkerNotificationScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '최근 알림',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                recentNoti.isEmpty
                                    ? '• 새 알림이 없습니다'
                                    : '• $recentNoti${recentNotiTime.isEmpty ? '' : ' ($recentNotiTime)'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── 현장 코드 등록 버튼 (파랑) → 22번 ──
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkerSiteScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6FA8F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '현장 코드 등록',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
