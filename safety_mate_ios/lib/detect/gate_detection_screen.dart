import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
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
import 'ppe_judge.dart';
import 'admin_password_dialog.dart';

const int gateTimeoutSeconds = 20;
const int detectIntervalMs = 1000;
const int resultShowMs = 3000;
const int maxHoldSeconds = 15;
const int retakeCountdownSeconds = 3;

const Set<String> gateLabels = {
  'helmet',
  'helmet_nostrap',
  'safety_shoes',
  'safety_gloves',
  'gaiters',
};

const bool gateUseFrontCamera = true;
const bool mirrorFrontBoxes = true;
const ResolutionPreset gateFrontResolution = ResolutionPreset.medium;

enum _GatePhase {
  scanning,
  pass,
  saving,
  saved,
  saveFailed,
  lowRecognition,
  retakeWait,
  askAdmin,
  adminDecide,
}

class GateDetectionScreen extends StatefulWidget {
  final String verifiedUserId;
  final String verifiedName;
  final int verifiedSiteId;

  const GateDetectionScreen({
    super.key,
    required this.verifiedUserId,
    required this.verifiedName,
    required this.verifiedSiteId,
  });

  @override
  State<GateDetectionScreen> createState() => _GateDetectionScreenState();
}

class _GateDetectionScreenState extends State<GateDetectionScreen> {
  final PpeDetector _detector = PpeDetector();
  final PpeRealtimeFilter _filter = PpeRealtimeFilter();

  CameraController? _controller;
  bool _modelReady = false;
  bool _cameraReady = false;
  String? _cameraError;

  String _siteName = '';

  _GatePhase _phase = _GatePhase.scanning;
  bool _started = false;
  bool _busy = false;
  bool _disposed = false;
  bool _popped = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _timer;
  int _remain = gateTimeoutSeconds;
  int _holdSeconds = 0;

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
  String? _dupLabel;
  bool _weakPending = false;
  String? _pairMissingMsg;

  int _attempt = 1;
  JudgeOutcome? _outcome;
  List<String> _pendingMissing = [];
  Timer? _retakeTimer;
  int _retakeRemain = retakeCountdownSeconds;

  bool get _holding => _dupLabel != null || _weakPending;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _detector.loadModel();
    if (!mounted) return;
    setState(() => _modelReady = true);

    _loadSiteName();

    await _initCamera();
    if (mounted && _controller != null) {
      _startScan();
    }
  }

  Future<void> _loadSiteName() async {
    try {
      final info = await ApiService.getMyInfo();
      if (mounted) {
        setState(() => _siteName = info['siteName']?.toString() ?? '');
      }
    } catch (e) {
      debugPrint('현장명 불러오기 실패: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = '카메라를 찾을 수 없어요');
        return;
      }
      final wantDir = gateUseFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == wantDir,
        orElse: () => cameras.first,
      );

      final bool isFront = cam.lensDirection == CameraLensDirection.front;
      final controller = CameraController(
        cam,
        isFront ? gateFrontResolution : ResolutionPreset.medium,
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
    _timer?.cancel();
    _retakeTimer?.cancel();
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

  Future<void> _startScan() async {
    final c = _controller;
    if (c == null || !_modelReady) return;

    _timer?.cancel();
    _filter.reset();
    setState(() {
      _started = true;
      _phase = _GatePhase.scanning;
      _remain = gateTimeoutSeconds;
      _holdSeconds = 0;
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
      _result = PpeRules.evaluate('', <String>{});
    });
    _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      if (!c.value.isStreamingImages) {
        await c.startImageStream(_onFrame);
      }
    } catch (e) {
      debugPrint('이미지 스트림 시작 오류: $e');
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _phase != _GatePhase.scanning) {
        t.cancel();
        return;
      }
      if (_holding && _holdSeconds < maxHoldSeconds) {
        setState(() => _holdSeconds++);
        return;
      }
      setState(() => _remain--);
      if (_remain <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
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

  void _onFrame(CameraImage frame) {
    if (_phase != _GatePhase.scanning || _busy || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastRun).inMilliseconds < detectIntervalMs) return;
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
    return PpeRules.evaluate('', labels);
  }

  Future<void> _processFrame(CameraImage frame) async {
    try {
      final data = FrameData.fromCameraImage(
        frame,
        _controller?.description.sensorOrientation ?? 90,
      );

      final image = await compute(convertYuvToImage, data);
      if (!mounted || _disposed || _phase != _GatePhase.scanning) return;

      final results = (await _detector.detect(
        image,
      )).where((d) => gateLabels.contains(d.label)).toList();

      if (!mounted || _disposed || _phase != _GatePhase.scanning) return;

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

      if (dup == null && result.allWorn) {
        _onPass();
      }
    } catch (e) {
      debugPrint('프레임 처리 오류: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _onPass() async {
    if (_phase != _GatePhase.scanning) return;
    _timer?.cancel();
    setState(() => _phase = _GatePhase.pass);
    await _stopStream();
    _autoNext();
  }

  Future<void> _onTimeout() async {
    if (_phase != _GatePhase.scanning) return;
    await _stopStream();
    if (!mounted) return;

    if (!_filter.hasAnyVisible) {
      setState(() => _phase = _GatePhase.lowRecognition);
      return;
    }
    if (_result?.allWorn ?? false) {
      _onPass();
      return;
    }

    final o = judgeAtEnd(
      workType: '',
      result: _result!,
      judgedLabels: _judgedLabels,
      filter: _filter,
    );
    _outcome = o;

    if (!o.hasAmbiguous) {
      _pendingMissing = o.missingLabels;
      _saveViolation();
      return;
    }
    if (_attempt == 1) {
      _startRetakeCountdown();
      return;
    }
    await _makeJudgePhoto();
    if (!mounted) return;
    setState(() => _phase = _GatePhase.askAdmin);
  }

  void _startRetakeCountdown() {
    _retakeTimer?.cancel();
    setState(() {
      _phase = _GatePhase.retakeWait;
      _retakeRemain = retakeCountdownSeconds;
    });
    _retakeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _phase != _GatePhase.retakeWait) {
        t.cancel();
        return;
      }
      if (_retakeRemain <= 1) {
        t.cancel();
        _beginRetake();
        return;
      }
      setState(() => _retakeRemain--);
    });
  }

  void _beginRetake() {
    if (!mounted || _phase != _GatePhase.retakeWait) return;
    _retakeTimer?.cancel();
    _attempt = 2;
    _startScan();
  }

  void _skipAdmin() {
    final o = _outcome;
    if (o != null && o.hasMissing) {
      _pendingMissing = o.missingLabels;
      _saveViolation();
    } else {
      _goNext();
    }
  }

  Future<void> _adminConfirm() async {
    final ok = await showAdminPasswordDialog(context);
    if (ok && mounted && _phase == _GatePhase.askAdmin) {
      setState(() => _phase = _GatePhase.adminDecide);
    }
  }

  void _adminRecordMissing() {
    final o = _outcome;
    if (o == null) return;
    _pendingMissing = o.allMissingLabels;
    _saveViolation();
  }

  void _adminAcceptWorn() {
    final o = _outcome;
    if (o == null) return;
    if (o.hasMissing) {
      _pendingMissing = o.missingLabels;
      _saveViolation();
    } else {
      setState(() => _phase = _GatePhase.pass);
      _autoNext();
    }
  }

  Future<void> _saveViolation() async {
    if (_judgePhoto == null && _lastImage == null) {
      if (mounted) setState(() => _phase = _GatePhase.saveFailed);
      return;
    }
    setState(() => _phase = _GatePhase.saving);

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

      final uuid =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

      await ApiService.saveDetection(
        clientUuid: uuid,
        targetUserId: widget.verifiedUserId,
        inspectorUserId: null,
        siteId: widget.verifiedSiteId,
        detectionMode: 'GATE',
        workType: null,
        s3Key: s3Key,
        items: items,
      );

      if (!mounted) return;
      setState(() => _phase = _GatePhase.saved);
      _autoNext();
    } catch (e) {
      debugPrint('저장 오류: $e');
      if (mounted) setState(() => _phase = _GatePhase.saveFailed);
    }
  }

  void _autoNext() {
    Future.delayed(const Duration(milliseconds: resultShowMs), _goNext);
  }

  void _goNext() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.pop(context);
  }

  bool _leaving = false;
  Future<void> _tryLeave() async {
    if (_phase == _GatePhase.pass || _phase == _GatePhase.saved) {
      _goNext();
      return;
    }
    if (_leaving) return;
    _leaving = true;
    final ok = await showAdminPasswordDialog(
      context,
      title: '감지 중단',
      message: '감지를 중단하려면 관리자 비밀번호를 입력하세요',
    );
    _leaving = false;
    if (ok) _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _tryLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141414),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _tryLeave,
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
                        const Text(
                          'Gate 모드',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _siteName.isNotEmpty ? _siteName : '현장',
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
              if (_started &&
                  _result != null &&
                  _phase != _GatePhase.lowRecognition)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
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
      ),
    );
  }

  Widget _buildBanner() {
    Color color;
    IconData icon;
    String title;
    String sub;
    bool showCountdown = false;

    switch (_phase) {
      case _GatePhase.scanning:
        color = const Color(0xFF534AB7);
        icon = Icons.verified_user;
        title =
            '${_attempt >= 2 ? "재촬영" : "인증 완료"} · ${widget.verifiedName.isEmpty ? "작업자" : widget.verifiedName}';
        if (_dupLabel != null) {
          color = const Color(0xFFBA7517);
          icon = Icons.groups;
          final ko = ppeLabelsKo[_dupLabel!] ?? _dupLabel!;
          sub = '⚠ $ko이(가) 여러 개 감지돼요 · 한 명씩 서주세요';
        } else if (_strapWarning) {
          sub = '⚠ 안전모 턱끈을 착용하세요';
        } else if (_weakPending) {
          sub = '흐리게 감지된 보호구가 있어요 · 가까이, 정면으로 서주세요';
        } else if (_pairMissingMsg != null) {
          sub = _pairMissingMsg!;
        } else if (_noDetectHint) {
          sub = '인식되지 않아요 · 전신이 화면에 보이게 서주세요';
        } else {
          sub = '카메라를 정면으로 보고 서주세요 · 전신이 보이게 · 한 명씩';
        }
        showCountdown = _started;
        break;
      case _GatePhase.pass:
        color = const Color(0xFF1D9E75);
        icon = Icons.check_circle;
        title = '입장 완료';
        sub = widget.verifiedName;
        break;
      case _GatePhase.saving:
        color = const Color(0xFFE24B4A);
        icon = Icons.warning_amber_rounded;
        title = '미착용 감지 · 입장 불가';
        sub = '기록 저장 중...';
        break;
      case _GatePhase.saved:
        color = const Color(0xFFE24B4A);
        icon = Icons.warning_amber_rounded;
        title = '미착용 감지 · 입장 불가';
        sub = '미착용 기록 완료 · 잠시 후 다음 사람';
        break;
      case _GatePhase.saveFailed:
        color = const Color(0xFFE24B4A);
        icon = Icons.error_outline;
        title = '미착용 감지 · 저장 실패';
        sub = '서버 연결을 확인하세요';
        break;
      case _GatePhase.lowRecognition:
        color = const Color(0xFFBA7517);
        icon = Icons.replay;
        title = '인식률 낮음';
        sub = '다시 시도해주세요 (각도·거리·조명 확인)';
        break;
      case _GatePhase.retakeWait:
        color = const Color(0xFFBA7517);
        icon = Icons.replay;
        title = '재촬영이 필요해요 · $_retakeRemain초 뒤 시작';
        sub =
            '흐리게 감지: ${_outcome?.ambiguousNames.join(", ") ?? ""} · 정면에서 전신이 보이게 서주세요';
        break;
      case _GatePhase.askAdmin:
        color = const Color(0xFFBA7517);
        icon = Icons.support_agent;
        title = '관리자에게 문의하세요';
        sub = _adminSubText();
        break;
      case _GatePhase.adminDecide:
        color = const Color(0xFF534AB7);
        icon = Icons.admin_panel_settings;
        title = '관리자 판단';
        sub = _adminSubText();
        break;
    }

    final bool paused =
        _phase == _GatePhase.scanning &&
        _holding &&
        _holdSeconds < maxHoldSeconds;

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
          if (showCountdown) ...[
            const SizedBox(width: 8),
            if (paused)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(Icons.pause, color: Colors.white, size: 18),
              ),
            Text(
              '$_remain초',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _adminSubText() {
    final o = _outcome;
    if (o == null) return '';
    final parts = <String>['흐리게 감지: ${o.ambiguousNames.join(", ")}'];
    if (o.missingNames.isNotEmpty) {
      parts.add('미착용: ${o.missingNames.join(", ")}');
    }
    return parts.join(' · ');
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
    if (photo != null &&
        (_phase == _GatePhase.askAdmin || _phase == _GatePhase.adminDecide)) {
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
    switch (_phase) {
      case _GatePhase.scanning:
        final bool paused = _holding && _holdSeconds < maxHoldSeconds;
        return _fullButton(
          !_started
              ? '준비 중...'
              : paused
              ? '판정 보류 · 다시 비춰주세요'
              : '자동 감지 중 · $_remain초 남음',
          const Color(0xFF3A3A3A),
          Colors.white70,
          null,
        );
      case _GatePhase.pass:
      case _GatePhase.saved:
        return _fullButton(
          '다음 사람',
          Colors.white,
          const Color(0xFF1A1A1A),
          _goNext,
        );
      case _GatePhase.saving:
        return _fullButton(
          '저장 중...',
          const Color(0xFF555555),
          Colors.grey,
          null,
        );
      case _GatePhase.saveFailed:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '다음 사람',
                const Color(0xFF3A3A3A),
                Colors.white,
                _goNext,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '저장 재시도',
                const Color(0xFFE24B4A),
                Colors.white,
                _saveViolation,
              ),
            ),
          ],
        );
      case _GatePhase.lowRecognition:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '다음 사람',
                const Color(0xFF3A3A3A),
                Colors.white,
                _goNext,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '다시 시도',
                Colors.white,
                const Color(0xFF1A1A1A),
                _startScan,
              ),
            ),
          ],
        );
      case _GatePhase.retakeWait:
        return _fullButton(
          '바로 재촬영',
          Colors.white,
          const Color(0xFF1A1A1A),
          _beginRetake,
        );
      case _GatePhase.askAdmin:
        return Row(
          children: [
            Expanded(
              child: _boxButton(
                '다음 사람',
                const Color(0xFF3A3A3A),
                Colors.white,
                _skipAdmin,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxButton(
                '관리자 확인',
                Colors.white,
                const Color(0xFF1A1A1A),
                _adminConfirm,
              ),
            ),
          ],
        );
      case _GatePhase.adminDecide:
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
    final bool isFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    return buildDetectionBoxes(
      constraints: constraints,
      detections: _detections,
      imgW: _imgW,
      imgH: _imgH,
      mirror: isFront && mirrorFrontBoxes && !Platform.isIOS,
    );
  }
}
