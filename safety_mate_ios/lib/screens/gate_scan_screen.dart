import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../detect/gate_detection_screen.dart';

class GateScanScreen extends StatefulWidget {
  const GateScanScreen({super.key});

  @override
  State<GateScanScreen> createState() => _GateScanScreenState();
}

class _GateScanScreenState extends State<GateScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.front,
  );
  bool isProcessing = false; // 검증 중 (중복 스캔 방지)

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // QR이 감지되면 호출됨
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => isProcessing = true);
    controller.stop();

    await _verifyToken(rawValue);
  }

  // 스캔한 토큰을 서버에 검증
  Future<void> _verifyToken(String qrToken) async {
    try {
      final result = await ApiService.verifyQr(qrToken: qrToken);
      if (!mounted) return;

      final valid = result['valid'] == true;
      final name = result['name'] ?? '';
      final message = result['message'] ?? '';

      if (valid) {
        // 유효 → 노동자 정보 꺼내고, 짧게 이름 표시 후 자동으로 감지 화면으로
        final userId = result['userId'] ?? '';
        final siteId = result['siteId']; // Integer 또는 null

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name 님 확인 · 감지를 시작합니다'),
            backgroundColor: AppColors.safe,
            duration: const Duration(milliseconds: 1200),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        // 감지 화면으로 이동 (노동자 정보 넘김, 갔다 오면 다시 스캔 대기)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GateDetectionScreen(
              verifiedUserId: userId,
              verifiedSiteId: (siteId is int)
                  ? siteId
                  : int.tryParse(siteId?.toString() ?? '') ?? 0,
              verifiedName: name,
            ),
          ),
        );

        // 감지 끝나고 돌아오면 → 다음 노동자 위해 다시 스캔
        _resetScan();
      } else {
        // 무효 → 거부 표시 후 자동 재스캔
        _showRejected(message.isNotEmpty ? message : '유효하지 않은 QR입니다');
      }
    } catch (e) {
      if (!mounted) return;
      _showRejected('QR을 확인할 수 없습니다');
    }
  }

  // 입장 거부 → 잠깐 표시하고 자동 재스캔
  void _showRejected(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('입장 거부: $reason'),
        backgroundColor: AppColors.danger,
        duration: const Duration(milliseconds: 1500),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1600), () {
      _resetScan();
    });
  }

  // 다시 스캔 가능하게 초기화
  void _resetScan() {
    if (!mounted) return;
    setState(() => isProcessing = false);
    controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          children: [
            Text(
              'Gate 모드',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(
              '노동자 QR 스캔',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onDetect),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF7C6BF0),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isProcessing ? 'QR 확인 중...' : '노동자의 QR 코드를 비춰주세요',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
