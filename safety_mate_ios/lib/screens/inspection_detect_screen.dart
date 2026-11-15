import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';
import '../services/ppe_detector.dart';
import 'inspection_worktype_screen.dart'; // WorkTypeGear, gearKoreanNames
import 'inspection_result_screen.dart';

class InspectionDetectScreen extends StatefulWidget {
  final WorkTypeGear workType;
  final String targetUserId;
  final String workerName;
  final String workerNick;

  const InspectionDetectScreen({
    super.key,
    required this.workType,
    required this.targetUserId,
    required this.workerName,
    required this.workerNick,
  });

  @override
  State<InspectionDetectScreen> createState() => _InspectionDetectScreenState();
}

class _InspectionDetectScreenState extends State<InspectionDetectScreen> {
  CameraController? _controller;
  final PpeDetector _detector = PpeDetector();
  bool _isReady = false;
  bool _isProcessing = false;
  bool _hasResult = false;
  String _status = '준비 중...';

  DateTime _lastDetect = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _detectIntervalMs = 1500;

  // 착용 인정 기준 (60% 이상만 착용 인정, 40~59%는 노랑 재인식)
  static const double _wearConf = 0.6;

  // 점검 제한 시간 (30초 카운트다운)
  static const int _limitSeconds = 30;
  int _remainSeconds = _limitSeconds;
  Timer? _countdownTimer;
  bool _timeUp = false;
  bool _streamStopped = false; // 카메라 스트림 중복 종료 방지

  // 쌍으로 착용하는 장비 (2개 이상이어야 착용 인정)
  static const List<String> pairGear = [
    'safety_gloves',
    'safety_shoes',
    'gaiters',
    'welding_gloves',
    'welding_gaiters',
    'chemical_gloves',
  ];

  CameraImage? _lastFrame;
  // 60% 이상 감지된 라벨별 개수
  Map<String, int> _countMap = {};
  Map<String, double> _confidence = {};
  String? _duplicateWarning;

  List<Detection> _detections = [];

  List<List<String>> get requiredGroups => widget.workType.requiredGroups;
  bool get isWelding => widget.workType.isWelding;

  // 그룹 충족 여부 (그룹 내 하나라도 착용 인정되면 OK)
  bool _groupOk(List<String> group) => group.any((g) => _isWorn(g));

  // 장비 착용 인정 여부 (쌍 장비는 2개, 단일은 1개, 60% 이상 기준)
  bool _isWorn(String gear) {
    // 안전모: 끈 풀린 게 60%↑로 잡히면 미착용 처리
    if (gear == 'helmet') {
      final nostrap = _countMap['helmet_nostrap'] ?? 0;
      if (nostrap >= 1) return false;
    }
    final cnt = _countMap[gear] ?? 0;
    return pairGear.contains(gear) ? cnt >= 2 : cnt >= 1;
  }

  bool get _allEquipped {
    final baseOk = requiredGroups.every(_groupOk);
    if (!isWelding) return baseOk;
    if (!baseOk) return false;
    final hasShield = _isWorn('welding_shield');
    if (hasShield) return true;
    final hasMask = _isWorn('dust_mask');
    final hasEye = _isWorn('safety_glasses') || _isWorn('face_shield');
    return hasMask && hasEye;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _detector.loadModel();

      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();

      if (!mounted) return;
      await _controller!.startImageStream(_onFrame);

      setState(() {
        _isReady = true;
        _status = _detector.isReady ? '감지 중... 노동자를 비춰주세요' : '모델 로드 실패';
      });
      _startCountdown();
    } catch (e) {
      setState(() => _status = '오류: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remainSeconds--;
        if (_remainSeconds <= 0) {
          _remainSeconds = 0;
          _timeUp = true;
          timer.cancel();
          _freezeDetection();
        }
      });
    });
  }

  // 시간 종료: 카메라 스트림 멈추고 마지막 감지 상태 고정
  Future<void> _freezeDetection() async {
    if (!_streamStopped) {
      _streamStopped = true;
      try {
        await _controller?.stopImageStream();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _status = '시간 종료 · 점검 완료를 눌러주세요';
    });
  }

  void _onFrame(CameraImage image) {
    if (_timeUp) return; // 시간 종료 후 감지 중단
    if (_isProcessing) return;
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

      // 이 작업종류에 필요한 장비만 남기기 (나머지는 화면·판정에서 제외)
      // 단, helmet_nostrap(끈 풀림)은 allGear에 없어도 항상 통과시켜 미착용 잡기
      final allowed = widget.workType.allGear;
      final results = rawResults
          .where(
            (d) => allowed.contains(d.label) || d.label == 'helmet_nostrap',
          )
          .toList();

      // 60% 이상만 개수 세기
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

      // 단일 장비 중복 감지 (쌍 장비 제외, 60%↑가 2개 이상)
      String? dupWarning;
      for (final entry in countMap.entries) {
        if (!pairGear.contains(entry.key) && entry.value >= 2) {
          final name = gearKoreanNames[entry.key] ?? entry.key;
          dupWarning = '$name가 중복 감지되었습니다 · 한 명씩 촬영해주세요';
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _countMap = countMap;
        _confidence = confMap;
        _detections = results;
        _hasResult = true;
        _duplicateWarning = dupWarning;
        if (dupWarning != null) {
          _status = dupWarning;
        } else {
          _status = _allEquipped ? '착용 완료' : '착용 확인 중...';
        }
      });
    } catch (e) {
      // 무시
    }
  }

  Future<void> _finishInspection() async {
    // 중복 감지 중엔 점검 완료 막기
    if (_duplicateWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_duplicateWarning!),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    List<int>? jpgBytes;
    if (_lastFrame != null) {
      final rgb = _convertYUV420toImage(_lastFrame!);
      if (rgb != null) {
        final boxed = drawDetectionsOnImage(rgb, _detections);
        jpgBytes = img.encodeJpg(boxed, quality: 85);
      }
    }

    if (!_streamStopped) {
      _streamStopped = true;
      try {
        await _controller?.stopImageStream();
      } catch (_) {}
    }
    if (!mounted) return;

    // 착용 인정된(60%↑, 쌍 장비 2개) 라벨만 결과로 넘김
    final wornLabels = <String>{};
    for (final label in _countMap.keys) {
      if (_isWorn(label)) wornLabels.add(label);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          workType: widget.workType,
          targetUserId: widget.targetUserId,
          workerName: widget.workerName,
          detectedLabels: wornLabels,
          confidence: Map<String, double>.from(_confidence),
          capturedImage: jpgBytes,
        ),
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context);
    });
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
    _countdownTimer?.cancel();
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
            Text(
              '${widget.workerName} · ${widget.workerNick}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.workType.name} 점검중',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 결과 배너
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: !_hasResult
                    ? Colors.white10
                    : (_duplicateWarning != null
                          ? AppColors.warning
                          : (_allEquipped ? AppColors.safe : AppColors.danger)),
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
                            : (_duplicateWarning != null
                                  ? Icons.groups
                                  : (_allEquipped
                                        ? Icons.check_circle_outline
                                        : Icons.search)),
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !_hasResult
                            ? '감지 대기'
                            : (_duplicateWarning != null
                                  ? '중복 감지'
                                  : (_allEquipped ? '착용 완료' : '착용 확인 중')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeUp ? '시간 종료' : '남은 시간 ${_remainSeconds}초',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
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

            // 하단 필수 PPE 요약 (그룹 단위)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 10,
                children: [
                  ...requiredGroups.map((group) => _groupItem(group)),
                  if (isWelding) _weldingExtraItem(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isReady ? _finishInspection : null,
                  child: const Text('점검 완료'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupItem(List<String> group) {
    final label = group.map((g) => gearKoreanNames[g] ?? g).join('/');
    final ok = _groupOk(group);
    return _summaryChip(label, ok);
  }

  Widget _weldingExtraItem() {
    final hasShield = _isWorn('welding_shield');
    if (hasShield) {
      return _summaryChip('보안면', true);
    } else {
      final hasMask = _isWorn('dust_mask');
      final hasEye = _isWorn('safety_glasses') || _isWorn('face_shield');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _summaryChip('방진', hasMask),
          const SizedBox(width: 8),
          _summaryChip('눈보호', hasEye),
        ],
      );
    }
  }

  Widget _summaryChip(String label, bool on) {
    final color = !_hasResult
        ? Colors.white38
        : (on ? AppColors.safe : AppColors.danger);
    final mark = !_hasResult ? '·' : (on ? 'V' : 'X');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mark,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

// 감지 박스 그리기 (0~1 정규화 좌표 → 화면 크기)
// 색: 60%↑ 초록 / 40~59% 노랑. 박스 얇게, 라벨 이름만
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
