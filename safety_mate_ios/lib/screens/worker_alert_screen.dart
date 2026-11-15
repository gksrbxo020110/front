import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class WorkerAlertScreen extends StatefulWidget {
  const WorkerAlertScreen({super.key});

  @override
  State<WorkerAlertScreen> createState() => _WorkerAlertScreenState();
}

class _WorkerAlertScreenState extends State<WorkerAlertScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 조회 실패: $e')));
    }
  }

  // 시각 포맷 (2026-10-06T14:20:00 → 2026.10.06 14:20)
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}.${two(dt.month)}.${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return '';
    }
  }

  // 알림 탭 → 읽음 처리 + 내용 팝업
  Future<void> _onTapNotification(Map<String, dynamic> n) async {
    final id = n['notificationId'];
    final isRead = n['isRead'] == true;

    // 안 읽은 거면 읽음 처리
    if (!isRead && id != null) {
      try {
        await ApiService.markNotificationRead(notificationId: id as int);
        if (mounted) setState(() => n['isRead'] = true);
      } catch (e) {
      }
    }

    if (!mounted) return;
    // 내용 팝업
    _showDetailDialog(n);
  }

  // 알림 내용 팝업
  void _showDetailDialog(Map<String, dynamic> n) {
    final message = n['message'] ?? '';
    final date = _formatDate(n['sentAt'] as String?);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            const Text(
              '미착용 알림',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '자세한 미착용 이력은\n현황 탭에서 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '알림',
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
            : RefreshIndicator(
                onRefresh: _load,
                child: _notifications.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Text(
                              '받은 알림이 없습니다',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          return _notificationCard(_notifications[index]);
                        },
                      ),
              ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final isRead = n['isRead'] == true;
    final message = n['message'] ?? '';
    final date = _formatDate(n['sentAt'] as String?);

    return GestureDetector(
      onTap: () => _onTapNotification(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFEBEE),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.danger,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isRead ? Icons.notifications_none : Icons.notifications_active,
              color: isRead ? AppColors.textSecondary : AppColors.danger,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
