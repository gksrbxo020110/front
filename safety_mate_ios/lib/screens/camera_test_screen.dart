import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';
import '../services/ppe_detector.dart';
import '../services/ppe_labels.dart';

class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  CameraController? _controller;
  final PpeDetector _detector = PpeDetector();
  bool _isReady = false;
  bool _isDetecting = false;
  String _status = '준비 중...';
  List<Detection> _results = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 모델 로드
      await _detector.loadModel();

      // 카메라 초기화
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {
        _isReady = true;
        _status = _detector.isReady ? '준비 완료 (촬영하세요)' : '모델 로드 실패';
      });
    } catch (e) {
      setState(() => _status = '오류: $e');
    }
  }

  // 촬영 → 감지
  Future<void> _captureAndDetect() async {
    if (_controller == null || _isDetecting) return;
    setState(() {
      _isDetecting = true;
      _status = '감지 중...';
      _results = [];
    });

    try {
      // 1. 사진 촬영
      final file = await _controller!.takePicture();

      // 2. 이미지 읽고 디코드
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        setState(() {
          _status = '이미지 디코드 실패';
          _isDetecting = false;
        });
        return;
      }

      // 3. 640x640으로 리사이즈
      final resized = img.copyResize(decoded, width: 640, height: 640);

      // 4. 모델 입력 형식으로 변환 [1][3][640][640], 0~1 정규화, 채널 우선
      final input = List.generate(
        1,
        (_) => List.generate(
          3,
          (c) => List.generate(
            640,
            (y) => List.generate(640, (x) {
              final pixel = resized.getPixel(x, y);
              // 채널별로: 0=R, 1=G, 2=B
              final value = c == 0
                  ? pixel.r
                  : c == 1
                  ? pixel.g
                  : pixel.b;
              return value / 255.0; // 0~1 정규화
            }),
          ),
        ),
      );

      // 5. 감지 실행
      final results = _detector.detect(input);

      setState(() {
        _results = results;
        _status = results.isEmpty ? '감지된 보호구 없음' : '${results.length}개 감지됨';
        _isDetecting = false;
      });
    } catch (e) {
      setState(() {
        _status = '감지 오류: $e';
        _isDetecting = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '감지 테스트',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF5F5F5),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 카메라 화면
            Expanded(
              flex: 3,
              child: _isReady && _controller != null
                  ? CameraPreview(_controller!)
                  : const Center(child: CircularProgressIndicator()),
            ),
            // 감지 결과 목록
            Expanded(
              flex: 2,
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        '촬영하면 감지 결과가 여기 표시됩니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final d = _results[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${d.koreanName} (${d.label})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(d.confidence * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.safe,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isReady
          ? FloatingActionButton.extended(
              onPressed: _isDetecting ? null : _captureAndDetect,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.camera_alt),
              label: Text(_isDetecting ? '감지 중...' : '촬영 & 감지'),
            )
          : null,
    );
  }
}
