import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class WorkerAlertSettingsScreen extends StatefulWidget {
  const WorkerAlertSettingsScreen({super.key});

  @override
  State<WorkerAlertSettingsScreen> createState() =>
      _WorkerAlertSettingsScreenState();
}

class _WorkerAlertSettingsScreenState extends State<WorkerAlertSettingsScreen> {
  bool _enabled = true; // 전체 알림
  bool _isLoading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final enabled = await ApiService.getNotificationSetting();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 설정 조회 실패: $e')));
    }
  }

  Future<void> _toggle(bool v) async {
    // 먼저 화면에 반영 (반응성)
    setState(() {
      _enabled = v;
      _updating = true;
    });
    try {
      final result = await ApiService.updateNotificationSetting(enabled: v);
      if (!mounted) return;
      setState(() {
        _enabled = result; // 서버 결과로 확정
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 실패 시 원래대로 되돌림
      setState(() {
        _enabled = !v;
        _updating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 설정 변경 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '알림 설정',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '알림 받기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '미착용 경고 등 알림을 받습니다',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            onChanged: _updating ? null : _toggle,
                            activeTrackColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // 안내 문구
                    Text(
                      _enabled
                          ? '알림이 켜져 있습니다.'
                          : '알림이 꺼져 있습니다. 미착용 경고를 받지 못할 수 있습니다.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
