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
import 'api_service.dart';

// Inspection 실시간 감지 설정값
const int inspDetectIntervalMs = 1000; // 감지 간격(ms)
const int inspResultShowMs = 1500; // 완료 표시 후 돌아가기까지(ms)

// 진행 단계
enum _InspPhase {
  scanning, // 실시간 감지 중
  saving, // 저장 중
  saved, // 완료 (착용 완료 = 저장 없이 완료 / 미착용 = 저장 완료)
  saveFailed, // 저장 실패
}

class InspectionDetectionScreen extends StatefulWidget {
  final String worker;
  final String nickname;
  final String userId; // 점검 대상 노동자 userId
  final String workType;
  final bool isPass; // (구 파라미터, 더 이상 안 씀 - 호환용)

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
  final PpeRealtimeFilter _filter = PpeRealtimeFilter(); // 공통 인정 규칙

  // 이 작업에서 보고 세는 라벨 (작업별 필수 장비만). 나머지는 박스·판정에서 무시
  // (게이트의 gateLabels와 같은 방식)
  late final Set<String> _workLabels = _labelsForWork(widget.workType);

  static Set<String> _labelsForWork(String workType) {
    final s = <String>{
      for (final r in PpeRules.requirementsFor(workType)) ...r.labels,
    };
    // 턱끈 없는 안전모는 안전모 판정(턱끈 경고)에 쓰니까 같이 봄
    if (s.contains('helmet')) s.add('helmet_nostrap');
    // 용접은 보안면 규칙이 evaluate에만 있어서 따로 추가
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

  int _siteId = 0; // 내 현장 (getMyInfo)

  _InspPhase _phase = _InspPhase.scanning;
  bool _busy = false;
  bool _disposed = false;
  bool _popped = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  List<Detection> _detections = []; // 현재 프레임, 작업별 필수 장비만 (표시할 때 40% 미만은 걸러짐)
  List<Detection> _lastShown = []; // 마지막 프레임의 초록+노랑 (저장 사진용)
  int _imgW = 0;
  int _imgH = 0;
  img.Image? _lastImage;

  InspectionResult? _result;
  Set<String> _judgedLabels = {}; // 실제 판정에 쓴 라벨 (턱끈 처리 후) → 저장 items 기준
  bool _noDetectHint = false;
  bool _strapWarning = false;
  bool _savedAllWorn = false; // 완료 시점 결과 (완료 문구용)
  String? _dupLabel; // 이번 프레임 중복 감지된 장비 (여러 명 의심)
  bool _weakPending = false; // 아직 인정 안 된 장비가 노랑으로 보임
  bool _gloveOneSide = false; // 장갑이 한쪽만 계속 보임

  @override
  void initState() {
    super.initState();
    _result = PpeRules.evaluate(widget.workType, <String>{}); // 처음엔 전부 ✗
    _init();
  }

  Future<void> _init() async {
    await _detector.loadModel();
    if (!mounted) return;
    setState(() => _modelReady = true);

    _loadSiteId(); // 서버 느려도 화면 안 막히게 await 안 함

    await _initCamera();
    if (mounted && _controller != null) {
      _startStream();
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

  // ── 실시간 감지 시작 ──
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

  // ── 다시 점검 (처음부터) ──
  Future<void> _restart() async {
    _filter.reset();
    setState(() {
      _phase = _InspPhase.scanning;
      _detections = [];
      _lastShown = [];
      _lastImage = null;
      _judgedLabels = {};
      _noDetectHint = false;
      _strapWarning = false;
      _dupLabel = null;
      _weakPending = false;
      _gloveOneSide = false;
      _result = PpeRules.evaluate(widget.workType, <String>{});
    });
    await _startStream();
  }

  // ── 카메라 프레임 도착 ──
  void _onFrame(CameraImage frame) {
    if (_phase != _InspPhase.scanning || _busy || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastRun).inMilliseconds < inspDetectIntervalMs) return;
    if (frame.planes.length < 3) return;

    _busy = true;
    _lastRun = now;
    _processFrame(frame);
  }

  // 인정된 라벨로 판정 (턱끈 처리 포함)
  InspectionResult _evaluateConfirmed() {
    final labels = _filter.confirmedLabels;
    bool strapWarning = false;
    if (labels.contains('helmet_nostrap') &&
        _filter.hitsOf('helmet_nostrap') >= _filter.hitsOf('helmet')) {
      labels.remove('helmet');
      strapWarning = true;
    }
    _strapWarning = strapWarning;
    _judgedLabels = labels; // 저장 items 기준
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

      // 작업별 필수 장비만 남김 → 박스(화면·저장 사진)·판정·노랑·중복 모두 이 기준
      final results = (await _detector.detect(
        image,
      )).where((d) => _workLabels.contains(d.label)).toList();
      if (!mounted || _disposed || _phase != _InspPhase.scanning) return;

      // 중복 감지 (1개짜리 장비가 2개 → 여러 명 의심) → 이번 프레임은 판정에 안 셈
      final strongNow = results.where(PpeRealtimeFilter.isStrong).toList();
      final String? dup = PpeRealtimeFilter.duplicateLabel(strongNow);
      if (dup == null) {
        _filter.addFrame(results);
      }
      final result = _evaluateConfirmed();

      // 노랑: 아직 인정 안 된 장비가 40~59%로 보임 → 관리자가 각도·거리 조절 요청
      final bool weakPending = results.any(
        (d) => PpeRealtimeFilter.isWeak(d) && !_judgedLabels.contains(d.label),
      );

      setState(() {
        _lastImage = image;
        _imgW = image.width;
        _imgH = image.height;
        _detections = results; // 박스 표시용 (작업별 필수만, 40% 미만은 그릴 때 걸러짐)
        _lastShown = results.where(PpeRealtimeFilter.isVisible).toList();
        _result = result;
        _noDetectHint = strongNow.isEmpty;
        _dupLabel = dup;
        _weakPending = weakPending;
        _gloveOneSide = _filter.anyPairMissing;
      });
    } catch (e) {
      debugPrint('프레임 처리 오류: $e');
    } finally {
      _busy = false;
    }
  }

  // ── 점검 완료 버튼 (B안: 미착용일 때만 저장 — 팀 약속·서버 설계와 동일) ──
  Future<void> _finish() async {
    if (_phase != _InspPhase.scanning) return;

    // 여러 명이 잡히는 중이면 판정 보류
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

    // ① 착용 완료 → 저장하지 않고 완료 표시 후 돌아가기
    //    (서버는 detection_records에 위반만 저장한다고 가정: "오늘 미착용 건수" 등)
    if (allWorn) {
      await _stopStream();
      if (!mounted) return;
      _savedAllWorn = true;
      setState(() => _phase = _InspPhase.saved);
      Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
      return;
    }

    // ② 미착용인데 초록 감지가 한 번도 없으면 저장 안 함 (빈 사진 저장 방지)
    if (!_filter.hasAnyStrong || _lastImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인식된 보호구가 없어요 · 작업자 전신을 화면에 비춰주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ③ 미착용 → 저장
    await _stopStream();
    _save();
  }

  // ── 저장 (B안: 미착용일 때만 여기로 옴 — _finish에서 걸러짐) ──
  Future<void> _save() async {
    if (_lastImage == null) {
      if (mounted) setState(() => _phase = _InspPhase.saveFailed);
      return;
    }
    _savedAllWorn = _result?.allWorn ?? false;
    setState(() => _phase = _InspPhase.saving);

    try {
      // 박스(초록+노랑, 작업별 필수만) 그린 사진 (iOS와 동일, 라벨 겹침 방지 포함)
      final bytes = await compute(
        drawBoxesAndEncode,
        BurnData.fromDetections(_lastImage!, _lastShown),
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

      // ② 미착용: 작업별 빠진 필수 항목을 worn=false로 (장갑 한쪽만도 여기로 들어감)
      for (final label in PpeRules.missingLabels(
        widget.workType,
        _judgedLabels,
      )) {
        final id = ppeLabels.indexOf(label);
        if (id == -1) continue;
        items.add(<String, dynamic>{
          'ppeId': id,
          'worn': false,
          'confidence': 0.0,
        });
      }

      // siteId를 아직 못 받았으면 한 번 더 시도
      if (_siteId == 0) await _loadSiteId();

      final uuid =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

      final saveRes = await ApiService.saveDetection(
        clientUuid: uuid,
        targetUserId: widget.userId,
        inspectorUserId: await ApiService.getUserId(), // 점검한 관리자
        siteId: _siteId,
        detectionMode: 'INSPECTION',
        workType: widget.workType,
        s3Key: s3Key,
        items: items,
      );

      if (!mounted) return;
      if (saveRes['success'] == true) {
        setState(() => _phase = _InspPhase.saved);
        Future.delayed(const Duration(milliseconds: inspResultShowMs), _goBack);
      } else {
        debugPrint('저장 실패: ${saveRes['body']}');
        setState(() => _phase = _InspPhase.saveFailed);
      }
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

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

            // ── 하단 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildBottom(),
            ),
          ],
        ),
      ),
    );
  }

  // 상태 배너
  Widget _buildBanner() {
    final bool allWorn = _result?.allWorn ?? false;
    Color color;
    IconData icon;
    String title;
    String sub;

    switch (_phase) {
      case _InspPhase.scanning:
        if (_dupLabel != null) {
          // 중복 → 주황 배너 (판정 보류)
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
          title = '착용 확인 중';
          if (_strapWarning) {
            sub = '⚠ 안전모 턱끈을 착용하세요';
          } else if (_weakPending) {
            sub = '흐리게 감지된 보호구가 있어요 · 각도·거리를 조절해주세요';
          } else if (_gloveOneSide) {
            sub = '⚠ 장갑을 양손에 모두 착용했는지 확인하세요';
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
        sub = widget.worker;
        break;
      case _InspPhase.saveFailed:
        color = const Color(0xFFE24B4A);
        icon = Icons.error_outline;
        title = '저장 실패';
        sub = '서버 연결을 확인하세요';
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
        ],
      ),
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

  // 하단 버튼
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

  // 바운딩박스 + 라벨 (초록/노랑, 작업별 필수만 / 라벨 겹침 방지는 ppe_box_overlay.dart)
  List<Widget> _buildBoxes(BoxConstraints constraints) {
    return buildDetectionBoxes(
      constraints: constraints,
      detections: _detections,
      imgW: _imgW,
      imgH: _imgH,
    );
  }
}
