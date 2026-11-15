import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class QrCreateScreen extends StatefulWidget {
  const QrCreateScreen({super.key});

  @override
  State<QrCreateScreen> createState() => _QrCreateScreenState();
}

class _QrCreateScreenState extends State<QrCreateScreen> {
  int selectedPeriod = 0;
  bool isLoading = false; // 발급 요청 중

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

  // QR 발급 요청
  Future<void> _createQr() async {
    setState(() => isLoading = true);
    try {
      await ApiService.issueQr(validDays: selectedValidDays);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR이 생성되었습니다'),
          backgroundColor: AppColors.safe,
          duration: Duration(seconds: 1),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context); // 생성 후 돌아감 (내 QR 화면이 다시 조회)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR 생성',
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
              // QR 생성 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR 코드를 생성하세요',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '현장 입장 시 사용됩니다',
                            style: TextStyle(
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
                onPressed: isLoading ? null : _createQr,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('생성하기'),
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
