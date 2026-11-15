import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';
import '../services/ppe_detector.dart';
import '../services/api_service.dart';

class GateDetectScreen extends StatefulWidget {
  final String targetUserId;
  final int? siteId;
  final String workerName;

  const GateDetectScreen({
    super.key,
    required this.targetUserId,
    required this.siteId,
    required this.workerName,
  });

  @override
  State<GateDetectScreen> createState() => _GateDetectScreenState();
}

class _GateDetectScreenState extends State<GateDetectScreen> {
  CameraController? _controller;
  final PpeDetector _detector = PpeDetector();
  bool _isReady = false;
  bool _isProcessing = false;
  bool _hasResult = false;
  bool _passed = false;
  bool _failed = false;
  bool _sending = false;
  String _status = '준비 중...';

  DateTime _lastDetect = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _detectIntervalMs = 1500;

  int _passStreak = 0;
  static const int _passThreshold = 2;

  Timer? _timeoutTimer;
  static const int _timeoutSeconds = 20;
  int _remainSeconds = _timeoutSeconds; // 화면 표시용 카운트다운

  // 착용 인정 기준 (이 이상이어야 착용으로 판정). 40~60%는 노랑(재인식)
  static const double _wearConf = 0.6;

  CameraImage? _lastFrame;
  Map<String, double> _lastConfidence = {};

  List<Detection> _detections = [];

  // 쌍으로 착용하는 장비 (2개 이상 감지돼야 착용 인정)
  static const List<String> pairGear = [
    'safety_gloves',
    'safety_shoes',
    'gaiters',
  ];

  static const List<String> requiredGear = [
    'helmet',
    'safety_shoes',
    'safety_gloves',
    'gaiters',
  ];

  // Gate 모드에서 화면·판정에 쓸 "허용 장비" (이 외엔 감지 결과에서 제거)
  // 필수 4종 + 턱끈 판정용 helmet_nostrap
  static const List<String> allowedLabels = [
    'helmet',
    'safety_shoes',
    'safety_gloves',
    'gaiters',
    'helmet_nostrap',
  ];

  static const Map<String, String> gearKorean = {
    'helmet': '안전모',
    'safety_shoes': '안전화',
    'safety_gloves': '안전장갑',
    'gaiters': '각반',
  };

  static const Map<String, String> allGearKorean = {
    'helmet': '안전모',
    'helmet_nostrap': '안전모',
    'safety_shoes': '안전화',
    'safety_gloves': '안전장갑',
    'gaiters': '각반',
    'safety_harness': '안전대',
    'safety_hook': '안전고리',
    'dust_mask': '방진마스크',
    'gas_mask': '방독마스크',
    'safety_glasses': '보안경',
    'face_shield': '안면보호대',
    'protective_suit': '보호복',
    'chemical_gloves': '내화학장갑',
    'welding_shield': '보안면',
    'welding_gloves': '용접장갑',
    'welding_gaiters': '용접각반',
  };

  static const Map<String, int> ppeIdMap = {
    'helmet': 5,
    'safety_shoes': 12,
    'safety_gloves': 9,
    'gaiters': 3,
  };

  Map<String, bool> _equipped = {
    'helmet': false,
    'safety_shoes': false,
    'safety_gloves': false,
    'gaiters': false,
  };

  bool _noStrap = false;
  String? _duplicateWarning;

  bool get _allEquipped => _equipped.values.every((v) => v);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _detector.loadModel();

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();

      if (!mounted) return;
      await _controller!.startImageStream(_onFrame);

      _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _remainSeconds--;
          if (_remainSeconds <= 0) {
            _remainSeconds = 0;
            timer.cancel();
            _onTimeout();
          }
        });
      });

      setState(() {
        _isReady = true;
        _status = _detector.isReady
            ? '카메라를 정면으로 보고 서주세요 · 전신이 보이게 · 한 명씩'
            : '모델 로드 실패';
      });
    } catch (e) {
      setState(() => _status = '오류: $e');
    }
  }

  void _onFrame(CameraImage image) {
    if (_isProcessing || _passed || _failed) return;
    final now = DateTime.now();
    if (now.difference(_lastDetect).inMilliseconds < _detectIntervalMs) return;

    _lastDetect = now;
    _isProcessing = true;
    _lastFrame = image;

    _processFrame(image)
        .then((_) {
          _isProcessing = false;
        })
        .catchError((_) {
          _isProcessing = false;
        });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final rgbImage = _convertYUV420toImage(image);
      if (rgbImage == null) return;

      final resized = img.copyResize(rgbImage, width: 640, height: 640);

      final input = List.generate(
        1,
        (_) => List.generate(
          3,
          (c) => List.generate(
            640,
            (y) => List.generate(640, (x) {
              final pixel = resized.getPixel(x, y);
              final value = c == 0
                  ? pixel.r
                  : c == 1
                  ? pixel.g
                  : pixel.b;
              return value / 255.0;
            }),
          ),
        ),
      );

      final rawResults = _detector.detect(input);

      // Gate 모드에서 필요한 장비만 남기기 (나머지는 화면·판정에서 제외)
      final results = rawResults
          .where((d) => allowedLabels.contains(d.label))
          .toList();

      // 착용 인정 기준(60%) 이상인 것만 개수 세기 (노랑 40~59%는 착용 미인정)
      final countMap = <String, int>{};
      for (final d in results) {
        if (d.confidence >= _wearConf) {
          countMap[d.label] = (countMap[d.label] ?? 0) + 1;
        }
      }

      final confMap = <String, double>{};
      for (final d in results) {
        final prev = confMap[d.label] ?? 0;
        if (d.confidence > prev) confMap[d.label] = d.confidence;
      }

      // 단일 장비 중복 감지 체크 (60% 이상 기준, 쌍 장비 제외하고 2개 이상)
      String? dupWarning;
      for (final entry in countMap.entries) {
        final label = entry.key;
        final cnt = entry.value;
        if (!pairGear.contains(label) && cnt >= 2) {
          final name = allGearKorean[label] ?? label;
          dupWarning = '$name가 중복 감지되었습니다 · 한 명씩 촬영해주세요';
          break;
        }
      }

      // 4종 착용 판정 (60% 이상 기준, 쌍 장비는 2개, 단일은 1개)
      final newEquipped = <String, bool>{};
      for (final gear in requiredGear) {
        final cnt = countMap[gear] ?? 0;
        if (pairGear.contains(gear)) {
          newEquipped[gear] = cnt >= 2;
        } else {
          newEquipped[gear] = cnt >= 1;
        }
      }

      // 턱끈 미착용 (helmet 60%↑ 없고 helmet_nostrap 60%↑ 있으면)
      final noStrap =
          (countMap['helmet'] ?? 0) == 0 &&
          (countMap['helmet_nostrap'] ?? 0) > 0;

      if (!mounted) return;

      final allOn = newEquipped.values.every((v) => v);

      setState(() {
        _equipped = newEquipped;
        _noStrap = noStrap;
        _hasResult = true;
        _lastConfidence = confMap;
        _detections = results; // 필터된 결과만 박스 그림
        _duplicateWarning = dupWarning;

        if (dupWarning != null) {
          _passStreak = 0;
          _status = dupWarning;
        } else if (allOn) {
          _passStreak++;
          _status = '착용 확인 중... (${_passStreak}/$_passThreshold)';
          if (_passStreak >= _passThreshold && !_passed) {
            _passed = true;
            _status = '입장 완료';
            _onPassed();
          }
        } else {
          _passStreak = 0;
          _status = '착용 확인 중...';
        }
      });
    } catch (e) {
      // 무시
    }
  }

  Future<void> _onPassed() async {
    _timeoutTimer?.cancel();
    await _controller?.stopImageStream();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _onTimeout() async {
    if (_passed || _failed || !mounted) return;

    if (_duplicateWarning != null) {
      _remainSeconds = _timeoutSeconds;
      _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _remainSeconds--;
          if (_remainSeconds <= 0) {
            _remainSeconds = 0;
            timer.cancel();
            _onTimeout();
          }
        });
      });
      return;
    }

    setState(() {
      _failed = true;
      _sending = true;
      _status = '미착용 확정 · 기록 전송 중...';
    });

    await _controller?.stopImageStream();

    try {
      await _sendViolation();
    } catch (e) {
      // 무시
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _status = '입장 불가';
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _sendViolation() async {
    List<int>? jpgBytes;
    if (_lastFrame != null) {
      final rgb = _convertYUV420toImage(_lastFrame!);
      if (rgb != null) {
        final boxed = drawDetectionsOnImage(rgb, _detections);
        jpgBytes = img.encodeJpg(boxed, quality: 85);
      }
    }

    String? s3Key;
    if (jpgBytes != null) {
      final urlInfo = await ApiService.getS3UploadUrl();
      s3Key = urlInfo['s3Key'];
      await ApiService.uploadImageToS3(
        uploadUrl: urlInfo['uploadUrl']!,
        imageBytes: jpgBytes,
      );
    }

    final items = requiredGear.map((gear) {
      return {
        'ppeId': ppeIdMap[gear],
        'worn': _equipped[gear] ?? false,
        'confidence': _lastConfidence[gear] ?? 0.0,
      };
    }).toList();

    final clientUuid =
        'gate_${DateTime.now().millisecondsSinceEpoch}_${widget.targetUserId}';

    await ApiService.saveDetection(
      clientUuid: clientUuid,
      targetUserId: widget.targetUserId,
      inspectorUserId: null,
      siteId: widget.siteId,
      detectionMode: 'GATE',
      workType: null,
      s3Key: s3Key,
      items: items,
    );
  }

  img.Image? _convertYUV420toImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final yPlane = image.planes[0];
      final yBuffer = yPlane.bytes;
      final yRowStride = yPlane.bytesPerRow;

      final out = img.Image(width: width, height: height);

      if (image.planes.length >= 3) {
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        final uBuffer = uPlane.bytes;
        final vBuffer = vPlane.bytes;
        final uvRowStride = uPlane.bytesPerRow;
        final uvPixelStride = uPlane.bytesPerPixel ?? 1;

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final yIndex = y * yRowStride + x;
            final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
            final yValue = yBuffer[yIndex];
            final uValue = uBuffer[uvIndex];
            final vValue = vBuffer[uvIndex];
            out.setPixelRgb(
              x,
              y,
              _yuv2r(yValue, uValue, vValue),
              _yuv2g(yValue, uValue, vValue),
              _yuv2b(yValue, uValue, vValue),
            );
          }
        }
      } else {
        final uvPlane = image.planes[1];
        final uvBuffer = uvPlane.bytes;
        final uvRowStride = uvPlane.bytesPerRow;
        final uvPixelStride = uvPlane.bytesPerPixel ?? 2;

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final yIndex = y * yRowStride + x;
            final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
            final yValue = yBuffer[yIndex];
            final uValue = uvBuffer[uvIndex];
            final vValue = uvBuffer[uvIndex + 1];
            out.setPixelRgb(
              x,
              y,
              _yuv2r(yValue, uValue, vValue),
              _yuv2g(yValue, uValue, vValue),
              _yuv2b(yValue, uValue, vValue),
            );
          }
        }
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  int _yuv2r(int y, int u, int v) =>
      (y + 1.402 * (v - 128)).round().clamp(0, 255);
  int _yuv2g(int y, int u, int v) =>
      (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
  int _yuv2b(int y, int u, int v) =>
      (y + 1.772 * (u - 128)).round().clamp(0, 255);

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Gate 모드',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.workerName.isNotEmpty ? widget.workerName : 'PPE 실시간 감지',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: !_hasResult
                    ? Colors.white10
                    : (_passed
                          ? AppColors.safe
                          : (_failed
                                ? AppColors.danger
                                : (_duplicateWarning != null
                                      ? AppColors.warning
                                      : (_allEquipped
                                            ? AppColors.safe
                                            : AppColors.danger)))),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !_hasResult
                            ? Icons.camera_alt_outlined
                            : (_passed
                                  ? Icons.verified
                                  : (_failed
                                        ? Icons.cancel
                                        : (_duplicateWarning != null
                                              ? Icons.groups
                                              : (_allEquipped
                                                    ? Icons.check_circle_outline
                                                    : Icons.search)))),
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !_hasResult
                            ? '감지 대기'
                            : (_passed
                                  ? '입장 완료'
                                  : (_failed
                                        ? '입장 불가'
                                        : (_duplicateWarning != null
                                              ? '중복 감지'
                                              : (_allEquipped
                                                    ? '착용 완료'
                                                    : '착용 확인 중')))),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!_passed && !_failed) ...[
                    const SizedBox(height: 4),
                    Text(
                      '남은 시간 ${_remainSeconds}초',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (_noStrap &&
                      !_passed &&
                      !_failed &&
                      _duplicateWarning == null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '⚠ 안전모 턱끈을 착용하세요',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 카메라 + 박스 오버레이
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isReady && _controller != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_controller!),
                              CustomPaint(
                                painter: _BoxPainter(detections: _detections),
                              ),
                            ],
                          );
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: requiredGear.map((gear) {
                  final isHelmetNoStrap = gear == 'helmet' && _noStrap;
                  return _summaryItem(
                    gearKorean[gear]!,
                    _equipped[gear] ?? false,
                    subLabel: isHelmetNoStrap ? '턱끈X' : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, bool on, {String? subLabel}) {
    final color = !_hasResult
        ? Colors.white38
        : (on ? AppColors.safe : AppColors.danger);
    final mark = !_hasResult ? '·' : (on ? 'V' : 'X');
    return Column(
      children: [
        Text(
          mark,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        if (subLabel != null)
          Text(
            subLabel,
            style: const TextStyle(color: AppColors.danger, fontSize: 10),
          ),
      ],
    );
  }
}

// 감지 박스 그리기 (0~1 정규화 좌표 → 화면 크기)
// 색: 60%↑ 초록 / 40~59% 노랑 (재인식 유도). 박스 얇게 (교수님 피드백)
class _BoxPainter extends CustomPainter {
  final List<Detection> detections;

  _BoxPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final bool high = d.confidence >= 0.6;
      final Color color = high
          ? const Color(0xFF00E676)
          : const Color(0xFFFFC107);

      final boxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color;

      final cx = d.box[0] * size.width;
      final cy = d.box[1] * size.height;
      final w = d.box[2] * size.width;
      final h = d.box[3] * size.height;

      final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
      canvas.drawRect(rect, boxPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ${d.koreanName} ',
          style: TextStyle(
            color: Colors.black,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            backgroundColor: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(rect.left + 1, rect.top + 1));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
