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
import 'ppe_pose.dart';
import 'api_service.dart';
import 'ppe_judge.dart';
import 'admin_password_dialog.dart';

// ─────────────────────────────────────────────
// 게이트 실시간 감지 설정값
// ─────────────────────────────────────────────
const int gateTimeoutSeconds = 20; // 제한 시간(초)
const int detectIntervalMs = 1000; // 감지 간격(ms) — 너무 줄이면 버벅임
const int resultShowMs = 2000; // 결과 보여주고 다음 사람까지 대기(ms)
const int maxHoldSeconds = 15; // 노랑·중복으로 타이머를 멈출 수 있는 최대 시간(초)
const int retakeCountdownSeconds = 3; // 재촬영 전 준비 시간(초) → 지나면 자동으로 다시 감지

// 게이트에서 보고 세는 라벨 (공통 4종 + 턱끈 없는 안전모). 나머지는 무시
const Set<String> gateLabels = {
  'helmet',
  'helmet_nostrap',
  'safety_shoes',
  'safety_gloves',
  'gaiters',
};

// ★ 임시: 모델에 들어가는 이미지를 카메라 영역 왼쪽 위에 작게 표시 (변환 확인용)
// 전면 카메라로 바꾼 뒤 사진이 똑바로 들어가는지 확인할 때만 true
const bool showDebugPreview = false;

// ★ 게이트 카메라: 전면(셀카) — 게이트 폰을 노동자 쪽으로 세워두고 화면을 보며 감지
const bool gateUseFrontCamera = true;
// 전면 미리보기는 거울처럼 좌우 반전돼서, 박스도 좌우 반전해서 그림
// (테스트했는데 박스가 반대쪽 손에 그려지면 false로)
const bool mirrorFrontBoxes = true;

// ★ 전면 카메라 해상도 (버벅임 테스트용)
// low = 가벼움(대신 작은 장갑·안전화 인식이 떨어질 수 있음) / medium = 원래 값
// 버벅임 줄었는데 박스가 잘 안 잡히면 medium으로 되돌리기
const ResolutionPreset gateFrontResolution = ResolutionPreset.medium;

// ★ 처리 시간 로그 (터미널에 ⏱ 줄) — 확인 끝나면 false
const bool showTimingLog = true;

// ★ 자세 인식(미착용 빨간 박스) — 팀 결정으로 보류. 둘 다 false면 자세 인식 자체를 안 돌림
// 다시 하게 되면 true로 바꾸면 바로 동작 (ppe_pose.dart 코드 유지)
const bool showPoseDots = false; // 확인용 노란 점
const bool showMissingBoxes = false; // 미착용 빨간 박스

// 게이트 진행 단계
enum _GatePhase {
  scanning, // 실시간 감지 중
  pass, // 입장 완료
  saving, // 미착용 저장 중
  saved, // 미착용 저장 완료
  saveFailed, // 저장 실패 (서버 꺼짐 등)
  lowRecognition, // 20초 동안 아무것도 안 보임 (초록·노랑 모두 없음)
  retakeWait, // 시간 종료 시 노랑(애매) → 재촬영 준비 (3초 뒤 자동 시작)
  askAdmin, // 재촬영에서도 노랑 → "관리자에게 문의하세요"
  adminDecide, // 관리자 비밀번호 확인 후 → 미착용 기록 / 착용 인정 선택
}

// ★ 임시: 확인용 미리보기 썸네일
Uint8List _makeThumb(img.Image image) {
  final t = img.copyResize(image, width: 120);
  return img.encodeJpg(t, quality: 70);
}

// ─────────────────────────────────────────────
// 화면
// ※ 프레임 변환·저장 사진 그리기는 ppe_frame_utils.dart (Inspection과 공통)
// ※ 인정 규칙(60%·노랑·장갑 2개·중복)은 ppe_realtime_filter.dart
// ─────────────────────────────────────────────
class GateDetectionScreen extends StatefulWidget {
  final String verifiedUserId; // QR 검증된 작업자 userId
  final String verifiedName; // 이름
  final int verifiedSiteId; // 현장 id

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
  final PpeRealtimeFilter _filter = PpeRealtimeFilter(); // 공통 인정 규칙
  final PpePose _pose = PpePose(); // 자세 인식 (스위치 꺼져 있으면 안 씀)

  CameraController? _controller;
  bool _modelReady = false;
  bool _cameraReady = false;
  String? _cameraError;

  String _siteName = '';

  _GatePhase _phase = _GatePhase.scanning;
  bool _started = false; // 감지 시작됐는지
  bool _busy = false; // 프레임 처리 중
  bool _disposed = false;
  bool _popped = false; // 중복 pop 방지
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _timer;
  int _remain = gateTimeoutSeconds;
  int _holdSeconds = 0; // 타이머를 멈춘 누적 시간

  // 현재 프레임 감지 결과 (게이트 4종만, 표시할 때 40% 미만은 걸러짐)
  List<Detection> _detections = [];
  List<Detection> _lastShown = []; // 마지막 프레임의 초록+노랑 (저장 사진에 그림)
  List<PosePoint> _posePoints = []; // 마지막 프레임의 자세 인식 점
  List<MissingRegion> _missingRegions = []; // 미착용 빨간 박스
  int _imgW = 0;
  int _imgH = 0;
  img.Image? _lastImage; // 마지막 프레임 (미착용 캡처용)
  // 관리자 판단용 사진 (팀 결정 11/10)
  //  - 노랑(애매)이 보인 마지막 프레임을 기억해 두었다가 관리자 화면에 멈춘 사진으로 보여줌
  //  - 관리자가 카메라 앞을 가려도 판단 근거가 그대로 + 저장도 이 사진 그대로 (본 사진 = 기록 사진)
  img.Image? _weakImage; // 노랑이 보인 마지막 프레임
  List<Detection> _weakShown = []; // 그 프레임의 초록+노랑
  Uint8List? _judgePhoto; // 박스 그린 판정 사진 (JPG)
  Uint8List? _debugThumb; // ★ 임시: 확인용 미리보기

  InspectionResult? _result;
  Set<String> _judgedLabels = {}; // 실제 판정에 쓴 라벨 (턱끈 처리 후) → 저장 items 기준
  bool _noDetectHint = false; // 현재 프레임에 초록 감지 없음
  bool _strapWarning = false; // 턱끈 없는 안전모로 판정됨
  String? _dupLabel; // 이번 프레임 중복 감지된 장비 (여러 명 의심)
  bool _weakPending = false; // 아직 인정 안 된 장비가 노랑으로 보임
  String? _pairMissingMsg; // 짝 장비(장갑·안전화·각반)가 한쪽만 보일 때 안내

  // 재촬영·관리자 확인 (팀 결정 11/9)
  int _attempt = 1; // 1 = 첫 촬영, 2 = 재촬영
  JudgeOutcome? _outcome; // 시간 종료 판정 (착용·미착용·애매)
  List<String> _pendingMissing = []; // 저장할 미착용 라벨 (저장 재시도용)
  Timer? _retakeTimer;
  int _retakeRemain = retakeCountdownSeconds;

  // 타이머를 멈춰야 하는 상황 (노랑 또는 중복)
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

    _loadSiteName(); // 서버 꺼져 있어도 화면 안 막히게 await 안 함

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
      // 게이트: 전면 카메라 (없으면 첫 번째 카메라)
      final wantDir = gateUseFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == wantDir,
        orElse: () => cameras.first,
      );

      // 전면이면 gateFrontResolution, 후면이면 원래대로 medium
      final bool isFront = cam.lensDirection == CameraLensDirection.front;
      final controller = CameraController(
        cam,
        isFront ? gateFrontResolution : ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (showTimingLog) {
        // ignore: avoid_print
        print(
          '📷 게이트 카메라: ${isFront ? "전면" : "후면"} · '
          '해상도 ${isFront ? gateFrontResolution.name : "medium"} · '
          '미리보기 ${controller.value.previewSize}',
        );
      }

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
    _pose.close();
    super.dispose();
  }

  // ── 감지 시작 (처음 + 다시 시도) ──
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
      _posePoints = [];
      _missingRegions = [];
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
      _result = PpeRules.evaluate('', <String>{}); // 처음엔 전부 ✗
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
      // 노랑·중복이면 타이머 멈춤 (최대 maxHoldSeconds까지만)
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

  // ── 카메라 프레임 도착 (초당 수십 번 불림 → 간격 두고 처리) ──
  void _onFrame(CameraImage frame) {
    if (_phase != _GatePhase.scanning || _busy || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastRun).inMilliseconds < detectIntervalMs) return;
    if (frame.planes.length < 3) return;

    _busy = true;
    _lastRun = now;
    _processFrame(frame);
  }

  // 인정된 라벨로 판정 (턱끈 처리 포함)
  InspectionResult _evaluateConfirmed() {
    final labels = _filter.confirmedLabels;
    bool strapWarning = false;

    // 턱끈 없는 안전모가 더 많이(같거나) 잡혔으면 → 안전모 미착용 + 턱끈 경고
    if (labels.contains('helmet_nostrap') &&
        _filter.hitsOf('helmet_nostrap') >= _filter.hitsOf('helmet')) {
      labels.remove('helmet');
      strapWarning = true;
    }
    _strapWarning = strapWarning;
    _judgedLabels = labels; // 저장 items 기준
    return PpeRules.evaluate('', labels);
  }

  Future<void> _processFrame(CameraImage frame) async {
    final sw = Stopwatch()..start(); // ⏱ 처리 시간 측정
    try {
      final data = FrameData.fromCameraImage(
        frame,
        _controller?.description.sensorOrientation ?? 90,
      );

      // 자세 인식은 스위치가 켜져 있을 때만 (YOLO와 동시에)
      final bool usePose = showPoseDots || showMissingBoxes;
      final Future<List<PosePoint>> poseFuture = usePose
          ? _pose.detect(data)
          : Future.value(const <PosePoint>[]);

      // 프레임 변환 (백그라운드)
      final image = await compute(convertYuvToImage, data);
      final int convertMs = sw.elapsedMilliseconds;
      if (!mounted || _disposed || _phase != _GatePhase.scanning) return;

      // 게이트는 공통 4종(+턱끈 없는 안전모)만 사용 → 다른 종류는 표시·판정 모두 제외
      final results = (await _detector.detect(
        image,
      )).where((d) => gateLabels.contains(d.label)).toList();
      final int yoloMs = sw.elapsedMilliseconds;

      final posePoints = await poseFuture;
      if (!mounted || _disposed || _phase != _GatePhase.scanning) return;
      if (showTimingLog) {
        // ignore: avoid_print
        print(
          '⏱ 프레임 ${image.width}x${image.height} · '
          '변환 ${convertMs}ms · 감지 ${yoloMs - convertMs}ms · '
          '전체 ${sw.elapsedMilliseconds}ms',
        );
      }

      // 중복 감지 (1개짜리 장비가 2개 → 여러 명 의심) → 이번 프레임은 판정에 안 셈
      final strongNow = results.where(PpeRealtimeFilter.isStrong).toList();
      final String? dup = PpeRealtimeFilter.duplicateLabel(strongNow);
      if (dup == null) {
        _filter.addFrame(results);
      }
      final result = _evaluateConfirmed();

      // 노랑: 아직 인정 안 된 장비가 40~59%로 보이면 → 타이머 멈춤 (재인식 유도)
      final bool weakPending = results.any(
        (d) => PpeRealtimeFilter.isWeak(d) && !_judgedLabels.contains(d.label),
      );

      // 미착용 빨간 박스 (스위치 켜져 있고 진짜 사람일 때만, 표시 전용)
      List<MissingRegion> missing = [];
      if (showMissingBoxes && isValidPerson(posePoints, image.height)) {
        missing = computeMissingRegions(
          points: posePoints,
          checkLabels: const [
            'helmet',
            'safety_gloves',
            'safety_shoes',
            'gaiters',
          ],
          presentLabels: {..._judgedLabels, ...strongNow.map((d) => d.label)},
          currentStrong: strongNow,
          strapMissing: _strapWarning,
        );
      }

      Uint8List? thumb;
      if (showDebugPreview) {
        thumb = await compute(_makeThumb, image);
        if (!mounted || _disposed) return;
      }

      setState(() {
        _lastImage = image;
        _imgW = image.width;
        _imgH = image.height;
        _detections = results; // 박스 표시용 (40% 미만은 그릴 때 걸러짐)
        _lastShown = results.where(PpeRealtimeFilter.isVisible).toList();
        if (weakPending) {
          _weakImage = image;
          _weakShown = _lastShown;
        }
        _posePoints = posePoints;
        _missingRegions = missing;
        _result = result;
        _noDetectHint = strongNow.isEmpty;
        _dupLabel = dup;
        _weakPending = weakPending;
        _pairMissingMsg = _filter.pairMissingMessage;
        if (thumb != null) _debugThumb = thumb;
      });

      // 중복이 아닐 때만 입장 완료 판정
      if (dup == null && result.allWorn) {
        _onPass();
      }
    } catch (e) {
      debugPrint('프레임 처리 오류: $e');
    } finally {
      _busy = false;
    }
  }

  // ── 공통 4종 충족 → 입장 완료 ──
  Future<void> _onPass() async {
    if (_phase != _GatePhase.scanning) return;
    _timer?.cancel();
    setState(() => _phase = _GatePhase.pass);
    await _stopStream();
    _autoNext();
  }

  // ── 20초 끝 → 착용 / 미착용 / 애매 판정 ──
  Future<void> _onTimeout() async {
    if (_phase != _GatePhase.scanning) return;
    await _stopStream();
    if (!mounted) return;

    if (!_filter.hasAnyVisible) {
      // 아무것도 안 보임 (초록·노랑 모두 없음) → 저장하지 않고 재시도 안내
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

    // 애매(노랑) 없음 → 확실한 미착용만 바로 기록
    if (!o.hasAmbiguous) {
      _pendingMissing = o.missingLabels;
      _saveViolation();
      return;
    }
    // 첫 촬영에서 노랑 → 기록 안 하고 재촬영
    if (_attempt == 1) {
      _startRetakeCountdown();
      return;
    }
    // 재촬영에서도 노랑 → 판정 사진을 멈춰 보여주고 관리자에게 문의
    await _makeJudgePhoto();
    if (!mounted) return;
    setState(() => _phase = _GatePhase.askAdmin);
  }

  // ── 재촬영 준비 (3초 뒤 자동으로 같은 사람 다시 감지, QR 다시 안 찍음) ──
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

  // ── "관리자에게 문의하세요"에서 [다음 사람] ──
  // 관리자가 없어도 확실한 미착용은 기록 (애매한 항목만 기록 안 함)
  void _skipAdmin() {
    final o = _outcome;
    if (o != null && o.hasMissing) {
      _pendingMissing = o.missingLabels;
      _saveViolation();
    } else {
      _goNext();
    }
  }

  // ── [관리자 확인] → 비밀번호 → 선택 화면 ──
  Future<void> _adminConfirm() async {
    final ok = await showAdminPasswordDialog(context);
    if (ok && mounted && _phase == _GatePhase.askAdmin) {
      setState(() => _phase = _GatePhase.adminDecide);
    }
  }

  // 관리자: 애매한 장비도 미착용으로 기록
  void _adminRecordMissing() {
    final o = _outcome;
    if (o == null) return;
    _pendingMissing = o.allMissingLabels;
    _saveViolation();
  }

  // 관리자: 애매한 장비는 착용으로 인정 → 안 보인 장비만 미착용, 없으면 입장 완료
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

  // ── 미착용 저장 (S3 + detections, detectionMode=GATE) ──
  // 저장할 미착용 라벨은 _pendingMissing (판정 결과 / 관리자 선택에 따라 다름)
  Future<void> _saveViolation() async {
    if (_judgePhoto == null && _lastImage == null) {
      if (mounted) setState(() => _phase = _GatePhase.saveFailed);
      return;
    }
    setState(() => _phase = _GatePhase.saving);

    try {
      // 마지막 프레임에 박스(초록+노랑) 그려서 JPG로 (공통 파일, 라벨 겹침 방지 포함)
      // 저장 사진은 실제 방향(좌우 반전 없음)
      // 관리자 화면에서 본 판정 사진이 있으면 그 사진 그대로 저장 (본 사진 = 기록 사진)
      final Uint8List bytes =
          _judgePhoto ??
          await compute(
            drawBoxesAndEncode,
            await BurnData.fromDetectionsKo(_lastImage!, _lastShown), // 한글 라벨
          );

      final urlRes = await ApiService.getS3UploadUrl();
      String? s3Key;
      if (urlRes['success'] == true) {
        final uploadUrl = urlRes['uploadUrl'];
        s3Key = urlRes['s3Key'];
        await ApiService.uploadImageToS3(uploadUrl, bytes);
      }

      // ── items ──
      // 서버는 worn=false 항목이 있어야 "미착용"으로 판단 (등급·알림·푸시)
      // ① 착용: 판정에 쓴 라벨만 worn=true (턱끈 없으면 helmet은 빠짐)
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

      // ② 미착용: 판정·관리자 선택에 따른 미착용 항목을 worn=false로 (짝 장비 한쪽만도 포함)
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

      final saveRes = await ApiService.saveDetection(
        clientUuid: uuid,
        targetUserId: widget.verifiedUserId,
        inspectorUserId: null, // 게이트 = null
        siteId: widget.verifiedSiteId,
        detectionMode: 'GATE',
        workType: null, // 게이트 = null
        s3Key: s3Key,
        items: items,
      );

      if (!mounted) return;
      if (saveRes['success'] == true) {
        setState(() => _phase = _GatePhase.saved);
        _autoNext();
      } else {
        debugPrint('저장 실패: ${saveRes['body']}');
        setState(() => _phase = _GatePhase.saveFailed);
      }
    } catch (e) {
      debugPrint('저장 오류: $e');
      if (mounted) setState(() => _phase = _GatePhase.saveFailed);
    }
  }

  // ── 결과 잠깐 보여주고 QR 화면으로 ──
  void _autoNext() {
    Future.delayed(const Duration(milliseconds: resultShowMs), _goNext);
  }

  void _goNext() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.pop(context);
  }

  // ── 뒤로가기 (화면 왼쪽 위 / 폰 뒤로가기) ──
  // 감지 도중 작업자가 뒤로 나가서 미착용 기록을 피하지 못하게, 결과가 끝난 뒤가 아니면 관리자 비밀번호 확인
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

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // 폰 뒤로가기도 같은 규칙 (결과 전이면 관리자 비밀번호)
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
            // ── 앱바 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

            // ── 상태 배너 ──
            _buildBanner(),
            const SizedBox(height: 12),

            // ── 카메라 영역 ──
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

            // ── 체크리스트 (인정된 것 기준) ──
            if (_started &&
                _result != null &&
                _phase != _GatePhase.lowRecognition)
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

            // ── 하단 버튼 ──
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

  // 상태 배너
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
          // 중복 → 주황 배너 (판정 보류)
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

  // 관리자 확인 화면 안내 (애매 / 확실한 미착용)
  String _adminSubText() {
    final o = _outcome;
    if (o == null) return '';
    final parts = <String>['흐리게 감지: ${o.ambiguousNames.join(", ")}'];
    if (o.missingNames.isNotEmpty) {
      parts.add('미착용: ${o.missingNames.join(", ")}');
    }
    return parts.join(' · ');
  }

  // ── 판정 사진 만들기 (노랑이 보인 프레임 우선, 없으면 마지막 프레임) ──
  Future<void> _makeJudgePhoto() async {
    final src = _weakImage ?? _lastImage;
    if (src == null) return;
    final shown = _weakImage != null ? _weakShown : _lastShown;
    try {
      _judgePhoto = await compute(
        drawBoxesAndEncode,
        await BurnData.fromDetectionsKo(src, shown), // 한글 라벨
      );
    } catch (e) {
      debugPrint('판정 사진 만들기 오류: $e');
    }
  }

  // 관리자 화면: 실시간 카메라 대신 판정 사진
  Widget _buildJudgePhoto(Uint8List photo) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.memory(photo, fit: BoxFit.contain, gaplessPlayback: true),
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

  // 카메라 영역
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

    // 관리자 판단 중 → 실시간 화면 대신 판정 사진 (관리자가 카메라 앞을 가려도 그대로)
    final photo = _judgePhoto;
    if (photo != null &&
        (_phase == _GatePhase.askAdmin ||
            _phase == _GatePhase.adminDecide)) {
      return _buildJudgePhoto(photo);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: Center(child: CameraPreview(c))),
            // 미착용 빨간 박스 (보류 중, 스위치 꺼짐)
            if (showMissingBoxes)
              ...buildMissingBoxes(
                constraints: constraints,
                regions: _missingRegions,
                imgW: _imgW,
                imgH: _imgH,
              ),
            ..._buildBoxes(constraints),
            // 확인용 자세 인식 점 (보류 중, 스위치 꺼짐)
            if (showPoseDots)
              ...buildPoseDots(
                constraints: constraints,
                points: _posePoints,
                imgW: _imgW,
                imgH: _imgH,
              ),
            // ★ 임시: 모델 입력 이미지 미리보기
            if (showDebugPreview && _debugThumb != null)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 1),
                  ),
                  child: Image.memory(
                    _debugThumb!,
                    width: 90,
                    gaplessPlayback: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 하단 버튼
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

  // 전체폭 버튼
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

  // 반폭 버튼
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

  // 바운딩박스 + 라벨 (초록/노랑, 라벨 겹침 방지는 ppe_box_overlay.dart)
  // 전면 카메라면 미리보기가 거울처럼 보이니까 박스도 좌우 반전
  List<Widget> _buildBoxes(BoxConstraints constraints) {
    final bool isFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    return buildDetectionBoxes(
      constraints: constraints,
      detections: _detections,
      imgW: _imgW,
      imgH: _imgH,
      mirror: isFront && mirrorFrontBoxes,
    );
  }
}
