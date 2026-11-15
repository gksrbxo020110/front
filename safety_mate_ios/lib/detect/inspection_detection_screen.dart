import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'ppe_detector.dart';
import 'ppe_labels.dart';
import 'ppe_rules.dart';
import 'ppe_realtime_filter.dart';
import 'ppe_frame_utils.dart';
import 'ppe_box_overlay.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'ppe_judge.dart';

const int inspDetectIntervalMs = 1000;
const int inspResultShowMs = 1500;
const int inspTimeoutSeconds = 30;

enum _InspPhase {
  scanning,
  saving,
  saved,
  saveFailed,
  noDetect,
  retakeWait,
  adminDecide,
}

class InspectionDetectionScreen extends StatefulWidget {
  final String worker;
  final String nickname;
  final String userId;
  final String workType;
  final bool isPass;

  const InspectionDetectionScreen({
    super.key,
    this.worker = '',
    this.nickname = '',
    this.userId = '',
    this.workType = '',
    this.isPass = false,
  });

  @override
  State<InspectionDetectionScreen> createState() =>
      _InspectionDetectionScreenState();
}

class _InspectionDetectionScreenState extends State<InspectionDetectionScreen> {
  final PpeDetector _detector = PpeDetector();
  final PpeRealtimeFilter _filter = PpeRealtimeFilter();

  late final Set<String> _workLabels = _labelsForWork(widget.workType);

  static Set<String> _labelsForWork(String workType) {
    final s = <String>{
      for (final r in PpeRules.requirementsFor(workType)) ...r.labels,
    };
    if (s.contains('helmet')) s.add('helmet_nostrap');
    if (workType.contains('용접')) {
      s.addAll(const [
        'welding_shield',
        'dust_mask',
        'face_shield',
        'safety_glasses',
      ]);
    }
    return s;
  }

  CameraController? _controller;
  bool _modelReady = false;
  bool _cameraReady = false;
  String? _cameraError;

  int _siteId = 0;

  _InspPhase _phase = _InspPhase.scanning;
  bool _busy = false;
  bool _disposed = false;
  bool _popped = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  List<Detection> _detections = [];
  List<Detection> _lastShown = [];
  int _imgW = 0;
  int _imgH = 0;
  img.Image? _lastImage;
  img.Image? _weakImage;
  List<Detection> _weakShown = [];
  Uint8List? _judgePhoto;

  InspectionResult? _result;
  Set<String> _judgedLabels = {};
  bool _noDetectHint = false;
  bool _strapWarning = false;
  bool _savedAllWorn = false;
  String? _dupLabel;
  bool _weakPending = false;
  String? _pairMissingMsg;

  Timer? _timer;
  int _remain = inspTimeoutSeconds;
  bool _autoJudged = false;

  int _attempt = 1;
  JudgeOutcome? _outcome;
  List<String> _pendingMissing = [];

  @override
  void initState() {
    super.initState();
    _result = PpeRules.evaluate(widget.workType, <String>{});
    _init();
  }

  Future<void> _init() async {
    await _detector.loadModel();
    if (!mounted) return;
    setState(() => _modelReady = true);

    _loadSiteId();

    await _initCamera();
    if (mounted && _controller != null) {
      _startStream();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _remain = inspTimeoutSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _disposed || _phase != _InspPhase.scanning) {
        t.cancel();
        return;
      }
      setState(() => _remain--);
      if (_remain <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onTimeout() async {
    if (_phase != _InspPhase.scanning) return;
    _autoJudged = true;
    await _stopStream();
    if (!mounted) return;

    final bool allWorn = _result?.allWorn ?? false;

    if (allWorn) {
      _savedAllWorn = true;
      setState(() => _phase = _InspPhase.saved);
      Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
      return;
    }

    if (!_filter.hasAnyVisible || _lastImage == null) {
      setState(() => _phase = _InspPhase.noDetect);
      return;
    }

    _judgeEnd();
  }

  Future<void> _judgeEnd() async {
    final o = judgeAtEnd(
      workType: widget.workType,
      result: _result!,
      judgedLabels: _judgedLabels,
      filter: _filter,
    );
    _outcome = o;

    if (!o.hasAmbiguous) {
      _pendingMissing = o.missingLabels;
      _save();
      return;
    }
    if (_attempt == 1) {
      setState(() => _phase = _InspPhase.retakeWait);
      return;
    }
    await _makeJudgePhoto();
    if (!mounted) return;
    setState(() => _phase = _InspPhase.adminDecide);
  }

  Future<void> _beginRetake() async {
    _attempt = 2;
    await _restart();
  }

  void _adminRecordMissing() {
    final o = _outcome;
    if (o == null) return;
    _pendingMissing = o.allMissingLabels;
    _save();
  }

  void _adminAcceptWorn() {
    final o = _outcome;
    if (o == null) return;
    if (o.hasMissing) {
      _pendingMissing = o.missingLabels;
      _save();
    } else {
      _savedAllWorn = true;
      setState(() => _phase = _InspPhase.saved);
      Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
    }
  }

  Future<void> _loadSiteId() async {
    try {
      final info = await ApiService.getMyInfo();
      if (!mounted) return;
      _siteId = (info['siteId'] is int)
          ? info['siteId']
          : int.tryParse(info['siteId']?.toString() ?? '') ?? 0;
    } catch (e) {
      debugPrint('siteId 불러오기 실패: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = '카메라를 찾을 수 없어요');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('카메라 초기화 오류: $e');
      if (mounted) setState(() => _cameraError = '카메라를 열 수 없어요');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) {
        c.stopImageStream().catchError((_) {});
      }
      c.dispose();
    }
    _detector.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    final c = _controller;
    if (c == null) return;
    _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      if (!c.value.isStreamingImages) {
        await c.startImageStream(_onFrame);
      }
    } catch (e) {
      debugPrint('이미지 스트림 시작 오류: $e');
    }
  }

  Future<void> _stopStream() async {
    final c = _controller;
    if (c != null && c.value.isStreamingImages) {
      try {
        await c.stopImageStream();
      } catch (e) {
        debugPrint('이미지 스트림 정지 오류: $e');
      }
    }
  }

  Future<void> _restart() async {
    _filter.reset();
    setState(() {
      _phase = _InspPhase.scanning;
      _detections = [];
      _lastShown = [];
      _lastImage = null;
      _weakImage = null;
      _weakShown = [];
      _judgePhoto = null;
      _judgedLabels = {};
      _noDetectHint = false;
      _strapWarning = false;
      _dupLabel = null;
      _weakPending = false;
      _pairMissingMsg = null;
      _autoJudged = false;
      _result = PpeRules.evaluate(widget.workType, <String>{});
    });
    await _startStream();
    _startTimer();
  }

  void _onFrame(CameraImage frame) {
    if (_phase != _InspPhase.scanning || _busy || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastRun).inMilliseconds < inspDetectIntervalMs) return;
    if (frame.planes.isEmpty) return;

    _busy = true;
    _lastRun = now;
    _processFrame(frame);
  }

  InspectionResult _evaluateConfirmed() {
    final labels = _filter.confirmedLabels;
    bool strapWarning = false;
    if (labels.contains('helmet_nostrap') &&
        _filter.hitsOf('helmet_nostrap') >= _filter.hitsOf('helmet')) {
      labels.remove('helmet');
      strapWarning = true;
    }
    _strapWarning = strapWarning;
    _judgedLabels = labels;
    return PpeRules.evaluate(widget.workType, labels);
  }

  Future<void> _processFrame(CameraImage frame) async {
    try {
      final data = FrameData.fromCameraImage(
        frame,
        _controller?.description.sensorOrientation ?? 90,
      );
      final image = await compute(convertYuvToImage, data);
      if (!mounted || _disposed || _phase != _InspPhase.scanning) return;

      final rawDetected = await _detector.detect(image);
      final results = rawDetected
          .where((d) => _workLabels.contains(d.label))
          .toList();
      if (!mounted || _disposed || _phase != _InspPhase.scanning) return;

      final strongNow = results.where(PpeRealtimeFilter.isStrong).toList();
      final String? dup = PpeRealtimeFilter.duplicateLabel(strongNow);
      if (dup == null) {
        _filter.addFrame(results);
      }
      final result = _evaluateConfirmed();

      final bool weakPending = results.any(
        (d) => PpeRealtimeFilter.isWeak(d) && !_judgedLabels.contains(d.label),
      );

      setState(() {
        _lastImage = image;
        _imgW = image.width;
        _imgH = image.height;
        _detections = results;
        _lastShown = results.where(PpeRealtimeFilter.isVisible).toList();
        if (weakPending) {
          _weakImage = image;
          _weakShown = _lastShown;
        }
        _result = result;
        _noDetectHint = strongNow.isEmpty;
        _dupLabel = dup;
        _weakPending = weakPending;
        _pairMissingMsg = _filter.pairMissingMessage;
      });
    } catch (e) {
      debugPrint('프레임 처리 오류: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _finish() async {
    if (_phase != _InspPhase.scanning) return;

    if (_dupLabel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('여러 명이 감지돼요 · 한 명씩 비춰주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final bool allWorn = _result?.allWorn ?? false;

    if (allWorn) {
      _stopTimer();
      await _stopStream();
      if (!mounted) return;
      _savedAllWorn = true;
      setState(() => _phase = _InspPhase.saved);
      Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
      return;
    }

    if (!_filter.hasAnyVisible || _lastImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인식된 보호구가 없어요 · 작업자 전신을 화면에 비춰주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _stopTimer();
    await _stopStream();
    if (!mounted) return;
    _judgeEnd();
  }

  Future<void> _save() async {
    if (_judgePhoto == null && _lastImage == null) {
      if (mounted) setState(() => _phase = _InspPhase.saveFailed);
      return;
    }
    _savedAllWorn = _result?.allWorn ?? false;
    setState(() => _phase = _InspPhase.saving);

    try {
      final Uint8List bytes =
          _judgePhoto ??
          await compute(
            drawBoxesAndEncode,
            await BurnData.fromDetectionsKo(_lastImage!, _lastShown),
          );

      String? s3Key;
      try {
        final urlInfo = await ApiService.getS3UploadUrl();
        s3Key = urlInfo['s3Key'];
        await ApiService.uploadImageToS3(
          uploadUrl: urlInfo['uploadUrl']!,
          imageBytes: bytes,
        );
      } catch (e) {
        debugPrint('S3 업로드 실패(무시하고 저장 진행): $e');
        s3Key = null;
      }

      final List<Map<String, dynamic>> items = _filter.confirmedDetections
          .where((d) => _judgedLabels.contains(d.label))
          .map(
            (d) => <String, dynamic>{
              'ppeId': ppeLabels.indexOf(d.label),
              'worn': true,
              'confidence': d.confidence,
            },
          )
          .where((it) => it['ppeId'] != -1)
          .toList();

      for (final label in _pendingMissing) {
        final id = ppeLabels.indexOf(label);
        if (id == -1) continue;
        items.add(<String, dynamic>{
          'ppeId': id,
          'worn': false,
          'confidence': 0.0,
        });
      }

      if (_siteId == 0) await _loadSiteId();

      final uuid =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

      await ApiService.saveDetection(
        clientUuid: uuid,
        targetUserId: widget.userId,
        inspectorUserId: await TokenStorage.getUserId(),
        siteId: _siteId,
        detectionMode: 'INSPECTION',
        workType: widget.workType,
        s3Key: s3Key,
        items: items,
      );

      if (!mounted) return;
      setState(() => _phase = _InspPhase.saved);
      Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
    } catch (e) {
      debugPrint('저장 오류: $e');
      if (mounted) setState(() => _phase = _InspPhase.saveFailed);
    }
  }

  void _goBack() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: const Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nickname.isNotEmpty
                            ? '${widget.worker} · @${widget.nickname}'
                            : widget.worker,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${widget.workType} 점검중',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildBanner(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCameraArea(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_result != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _result!.checklist.map((item) {
                    final bool showStrap =
                        item.displayName == '안전모' && _strapWarning;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.worn ? Icons.check : Icons.close,
                          size: 15,
                          color: item.worn
                              ? const Color(0xFF5FBB46)
                              : const Color(0xFFE24B4A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          showStrap ? '안전모 (턱끈X)' : item.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.worn
                                ? const Color(0xFF9FE1CB)
                                : const Color(0xFFF09595),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildBottom(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final bool allWorn = _result?.allWorn ?? false;
    Color color;
    IconData icon;
    String title;
    String sub;

    switch (_phase) {
      case _InspPhase.scanning:
        if (_dupLabel != null) {
          color = const Color(0xFFBA7517);
          icon = Icons.groups;
          title = '판정 보류';
          final ko = ppeLabelsKo[_dupLabel!] ?? _dupLabel!;
          sub = '⚠ $ko이(가) 여러 개 감지돼요 · 한 명씩 비춰주세요';
        } else if (allWorn) {
          color = const Color(0xFF1D9E75);
          icon = Icons.check_circle;
          title = '착용 완료 · 작업 가능';
          sub = '점검 완료를 눌러 마치세요';
        } else {
          color = const Color(0xFFE24B4A);
          icon = Icons.search;
          title = _attempt >= 2 ? '재촬영 · 착용 확인 중' : '착용 확인 중';
          if (_strapWarning) {
            sub = '⚠ 안전모 턱끈을 착용하세요';
          } else if (_weakPending) {
            sub = '흐리게 감지된 보호구가 있어요 · 각도·거리를 조절해주세요';
          } else if (_pairMissingMsg != null) {
            sub = _pairMissingMsg!;
          } else if (_noDetectHint) {
            sub = '인식되지 않아요 · 작업자 전신이 보이게 비춰주세요';
          } else {
            sub = '작업자 전신을 비춰주세요 · 한 명씩';
          }
        }
        break;
      case _InspPhase.saving:
        color = _savedAllWorn
            ? const Color(0xFF1D9E75)
            : const Color(0xFFE24B4A);
        icon = Icons.cloud_upload;
        title = '점검 결과 저장 중...';
        sub = widget.worker;
        break;
      case _InspPhase.saved:
        color = _savedAllWorn
            ? const Color(0xFF1D9E75)
            : const Color(0xFFE24B4A);
        icon = _savedAllWorn ? Icons.check_circle : Icons.warning_amber_rounded;
        title = _savedAllWorn ? '점검 완료 · 이상 없음' : '점검 완료 · 미착용 기록됨';
        sub = _autoJudged
            ? '제한 시간 종료 · 자동 판정 (${widget.worker})'
            : widget.worker;
        break;
      case _InspPhase.saveFailed:
        color = const Color(0xFFE24B4A);
        icon = Icons.error_outline;
        title = '저장 실패';
        sub = '서버 연결을 확인하세요';
        break;
      case _InspPhase.noDetect:
        color = const Color(0xFFBA7517);
        icon = Icons.timer_off_outlined;
        title = '시간 초과 · 인식 실패';
        sub = '보호구가 인식되지 않아 판정할 수 없어요 · 다시 점검해주세요';
        break;
      case _InspPhase.retakeWait:
        color = const Color(0xFFBA7517);
        icon = Icons.replay;
        title = '재촬영이 필요해요';
        sub =
            '흐리게 감지: ${_outcome?.ambiguousNames.join(", ") ?? ""} · 각도·거리를 조절하고 다시 점검하세요';
        break;
      case _InspPhase.adminDecide:
        color = const Color(0xFF534AB7);
        icon = Icons.admin_panel_settings;
        title = '관리자 판단';
        final o = _outcome;
        final parts = <String>[
          '흐리게 감지: ${o?.ambiguousNames.join(", ") ?? ""}',
          if (o != null && o.missingNames.isNotEmpty)
            '미착용: ${o.missingNames.join(", ")}',
        ];
        sub = parts.join(' · ');
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_phase == _InspPhase.scanning && _timer != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_remain}s',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _makeJudgePhoto() async {
    final src = _weakImage ?? _lastImage;
    if (src == null) return;
    final shown = _weakImage != null ? _weakShown : _lastShown;
    try {
      _judgePhoto = await compute(
        drawBoxesAndEncode,
        await BurnData.fromDetectionsKo(src, shown),
      );
    } catch (e) {
      debugPrint('판정 사진 만들기 오류: $e');
    }
  }

  Widget _buildJudgePhoto(Uint8List photo) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.memory(
            photo,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '판정 순간 사진 · 미착용 기록 시 이 사진으로 저장',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraArea() {
    final c = _controller;
    if (_cameraError != null || !_cameraReady || c == null || !_modelReady) {
      String msg;
      if (_cameraError != null) {
        msg = _cameraError!;
      } else if (!_modelReady) {
        msg = '모델 불러오는 중...';
      } else {
        msg = '카메라 준비 중...';
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 70, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final photo = _judgePhoto;
    if (photo != null && (_phase == _InspPhase.adminDecide)) {
      return _buildJudgePhoto(photo);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: Center(child: CameraPreview(c))),
            ..._buildBoxes(constraints),
          ],
        );
      },
    );
  }

  Widget _buildBottom() {
    final bool ready = _modelReady && _cameraReady;
    switch (_phase) {
      case _InspPhase.scanning:
        return _fullButton(
          '점검 완료',
          ready ? Colors.white : const Color(0xFF555555),
          ready ? const Color(0xFF1A1A1A) : Colors.grey,
          ready ? _finish : null,
        );
      case _InspPhase.saving:
        return _fullButton(
          '저장 중...',
          const Color(0xFF555555),
          Colors.grey,
          null,
        );
      case _InspPhase.saved:
        return _fullButton(
          '돌아가기',
          Colors.white,
          const Color(0xFF1A1A1A),
          _goBack,
        );
      case _InspPhase.noDetect:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '돌아가기',
                const Color(0xFF3A3A3A),
                Colors.white,
                _goBack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '다시 점검',
                const Color(0xFFBA7517),
                Colors.white,
                _restart,
              ),
            ),
          ],
        );
      case _InspPhase.saveFailed:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '다시 점검',
                const Color(0xFF3A3A3A),
                Colors.white,
                _restart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '저장 재시도',
                const Color(0xFFE24B4A),
                Colors.white,
                _save,
              ),
            ),
          ],
        );
      case _InspPhase.retakeWait:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '돌아가기',
                const Color(0xFF3A3A3A),
                Colors.white,
                _goBack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '다시 점검',
                Colors.white,
                const Color(0xFF1A1A1A),
                _beginRetake,
              ),
            ),
          ],
        );
      case _InspPhase.adminDecide:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '미착용으로 기록',
                const Color(0xFFE24B4A),
                Colors.white,
                _adminRecordMissing,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '착용으로 인정',
                const Color(0xFF1D9E75),
                Colors.white,
                _adminAcceptWorn,
              ),
            ),
          ],
        );
    }
  }

  Widget _fullButton(String text, Color bg, Color fg, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _boxButton(String text, Color bg, Color fg, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBoxes(BoxConstraints constraints) {
    return buildDetectionBoxes(
      constraints: constraints,
      detections: _detections,
      imgW: _imgW,
      imgH: _imgH,
    );
  }
}
