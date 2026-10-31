import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanTestScreen extends StatefulWidget {
  const QrScanTestScreen({super.key});

  @override
  State<QrScanTestScreen> createState() => _QrScanTestScreenState();
}

class _QrScanTestScreenState extends State<QrScanTestScreen> {
  String result = '아직 스캔 안 됨';
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'QR 스캔 테스트',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 카메라 화면 (QR 스캔)
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  if (scanned) return; // 한 번만 처리
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    setState(() {
                      scanned = true;
                      result = barcodes.first.rawValue ?? '내용 없음';
                    });
                  }
                },
              ),
            ),

            // 스캔 결과 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.black,
              child: Column(
                children: [
                  const Text(
                    '스캔 결과',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (scanned)
                    GestureDetector(
                      onTap: () => setState(() {
                        scanned = false;
                        result = '아직 스캔 안 됨';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '다시 스캔',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
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
