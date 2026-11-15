import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class QrRenewScreen extends StatefulWidget {
  final String? expireAt; // 현재 QR 만료일 (내 QR 화면에서 넘겨받음)

  const QrRenewScreen({super.key, this.expireAt});

  @override
  State<QrRenewScreen> createState() => _QrRenewScreenState();
}

class _QrRenewScreenState extends State<QrRenewScreen> {
  int selectedPeriod = 0; // 0=당일, 1=주간, 2=월간
  bool isLoading = false; // 갱신 요청 중

  final List<String> periods = ['당일 (오늘 자정 만료)', '주간 (7일)', '월간 (최대 1개월)'];

  // 선택한 유효기간 → 서버에 보낼 validDays
  int get selectedValidDays {
    switch (selectedPeriod) {
      case 0:
        return 1; // 당일
      case 1:
        return 7; // 주간
      case 2:
        return 30; // 월간
      default:
        return 1;
    }
  }

  // 만료 경고 문구 (expireAt → "2026.08.26 까지 (D-1)")
  String _expireWarning() {
    if (widget.expireAt == null) return '';
    try {
      final dt = DateTime.parse(widget.expireAt!);
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      // 남은 일수 계산 (오늘 자정 기준)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expireDay = DateTime(dt.year, dt.month, dt.day);
      final daysLeft = expireDay.difference(today).inDays;

      final leftText = daysLeft > 0
          ? '$daysLeft일 남음'
          : (daysLeft == 0 ? '오늘 만료' : '만료됨');
      return '$y.$m.$d 까지 ($leftText)';
    } catch (_) {
      return '';
    }
  }

  // QR 갱신 (= 재발급, 같은 issue API)
  Future<void> _renewQr() async {
    setState(() => isLoading = true);
    try {
      await ApiService.issueQr(validDays: selectedValidDays);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR이 갱신되었습니다'),
          backgroundColor: AppColors.safe,
          duration: Duration(seconds: 1),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR 갱신 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warning = _expireWarning();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR 갱신',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 현재 QR 만료 안내 (만료일 있으면 표시)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '현재 QR 만료 안내',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            warning.isNotEmpty
                                ? warning
                                : '갱신하면 새 유효기간으로 재발급됩니다',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '유효기간 선택',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              ...List.generate(periods.length, (i) => _periodOption(i)),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _renewQr,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('갱신하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodOption(int index) {
    final selected = selectedPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => selectedPeriod = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDE7F6) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(periods[index], style: const TextStyle(fontSize: 14)),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
