import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'ppe_detector.dart';
import 'ppe_frame_utils.dart';

// ─────────────────────────────────────────────
// 자세 인식 (Google ML Kit Pose) — 미착용 빨간 박스 위치 찾기용
// YOLO 판정에는 관여하지 않음 (표시 전용)
// ─────────────────────────────────────────────

// ★ 조정용 숫자 (캡처 보고 여기만 바꾸면 됨) ─────────────
const double poseMinLikelihood = 0.5; // 이 확률 이상인 점만 "보인다"고 봄

// 가짜 사람 걸러내기
const double personTorsoMinLikelihood = 0.7; // 어깨·엉덩이 점 최소 확률
const double personMinTorsoRatio = 0.08; // 어깨~엉덩이 길이 ≥ 화면 높이 × 이 값

// 빨간 박스 모양
const double headWidthScale = 1.6; // 머리 폭 = 귀 간격(없으면 눈 간격×2) × 이 값
const double headHeightScale = 1.1; // 머리 높이 = 머리 폭 × 이 값
const double headUpRatio = 0.75; // 눈 위치에서 머리 높이의 몇 배만큼 위로 올릴지
const double handSizeScale = 0.7; // 손 박스 한 변 = 팔뚝(팔꿈치~손목) × 이 값
const double footSizeScale = 0.5; // 발 박스 한 변 = 정강이(무릎~발목) × 이 값
const double shinPartRatio = 0.55; // 각반 = 발목에서 무릎 쪽으로 정강이의 몇 %까지
const double shinWidthScale = 0.4; // 각반 폭 = 정강이 길이 × 이 값
const double coverMargin = 0.2; // 보호구 박스를 이만큼 넓혀서 "그 부위를 덮었는지" 판단
const double fallbackSize = 40; // 길이를 못 재면 쓸 기본 크기(px)
// ─────────────────────────────────────────────

// 몸의 점 하나 (이미지 픽셀 좌표 — YOLO 박스와 같은 세로 기준)
class PosePoint {
  final String name; // 예: nose, leftWrist, rightAnkle
  final double x;
  final double y;
  final double likelihood; // 화면 안에 보일 확률 (0~1)
  const PosePoint(this.name, this.x, this.y, this.likelihood);
}

// 미착용 빨간 박스 하나 (이미지 픽셀 좌표)
class MissingRegion {
  final String text; // 예: "안전모 미착용"
  final Rect rect;
  const MissingRegion(this.text, this.rect);
}

// 빨간 박스 라벨에 쓸 한글 이름
const Map<String, String> missingNameKo = {
  'helmet': '안전모',
  'safety_gloves': '안전장갑',
  'safety_shoes': '안전화',
  'gaiters': '각반',
};

// YUV420(3개 판) → NV21(Y + VU 교차) 변환 — ML Kit 안드로이드 입력 형식
// compute로 백그라운드 실행
Uint8List yuvToNv21(FrameData f) {
  final int w = f.width;
  final int h = f.height;
  final out = Uint8List(w * h + (w * h ~/ 2));
  int o = 0;

  // Y (줄마다 여분 바이트 제거)
  for (int row = 0; row < h; row++) {
    final int start = row * f.yRowStride;
    final int end = min(start + w, f.y.length);
    if (end > start) {
      out.setRange(o, o + (end - start), f.y, start);
    }
    o += w;
  }

  // VU 교차 (2x2 픽셀마다 1쌍)
  for (int row = 0; row < h ~/ 2; row++) {
    final int uvRow = row * f.uvRowStride;
    for (int col = 0; col < w ~/ 2; col++) {
      final int idx = uvRow + col * f.uvPixelStride;
      out[o++] = idx < f.v.length ? f.v[idx] : 128;
      out[o++] = idx < f.u.length ? f.u[idx] : 128;
    }
  }
  return out;
}

class PpePose {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base, // 빠른 모델
      mode: PoseDetectionMode.stream, // 실시간용
    ),
  );
  bool _closed = false;

  // 프레임 → 몸의 점 목록 (사람 없으면 빈 목록, 실패해도 빈 목록)
  Future<List<PosePoint>> detect(FrameData f) async {
    if (_closed) return [];
    try {
      final bytes = await compute(yuvToNv21, f);
      if (_closed) return [];

      final rotation =
          InputImageRotationValue.fromRawValue(f.rotation) ??
          InputImageRotation.rotation90deg;

      final input = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(f.width.toDouble(), f.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: f.width,
        ),
      );

      final poses = await _detector.processImage(input);
      if (poses.isEmpty) return [];

      // 한 명만 사용 ("한 명씩 서주세요")
      return poses.first.landmarks.values
          .map((l) => PosePoint(l.type.name, l.x, l.y, l.likelihood))
          .toList();
    } catch (e) {
      debugPrint('자세 인식 오류: $e');
      return [];
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await _detector.close();
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────
// 미착용 빨간 박스 계산
// ─────────────────────────────────────────────

// 확률 기준 이상인 점만 이름으로 찾기 쉽게
Map<String, PosePoint> _visible(List<PosePoint> points, double minLike) {
  final m = <String, PosePoint>{};
  for (final p in points) {
    if (p.likelihood >= minLike) m[p.name] = p;
  }
  return m;
}

double _dist(PosePoint a, PosePoint b) =>
    sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

// 진짜 사람인지 (카페 배경 같은 가짜 점 걸러내기)
bool isValidPerson(List<PosePoint> points, int imgH) {
  final m = _visible(points, personTorsoMinLikelihood);
  final ls = m['leftShoulder'];
  final rs = m['rightShoulder'];
  if (ls == null || rs == null) return false;
  final hips = [m['leftHip'], m['rightHip']].whereType<PosePoint>().toList();
  if (hips.isEmpty) return false;

  final double shoulderY = (ls.y + rs.y) / 2;
  final double hipY =
      hips.map((p) => p.y).reduce((a, b) => a + b) / hips.length;
  return (hipY - shoulderY) >= imgH * personMinTorsoRatio;
}

// 머리(안전모) 자리
Rect? _headRect(Map<String, PosePoint> p) {
  final face = [
    p['nose'],
    p['leftEye'],
    p['rightEye'],
    p['leftEar'],
    p['rightEar'],
  ].whereType<PosePoint>().toList();
  if (face.length < 2) return null;

  final double cx = face.map((e) => e.x).reduce((a, b) => a + b) / face.length;

  double? span;
  if (p['leftEar'] != null && p['rightEar'] != null) {
    span = (p['leftEar']!.x - p['rightEar']!.x).abs();
  } else if (p['leftEye'] != null && p['rightEye'] != null) {
    span = (p['leftEye']!.x - p['rightEye']!.x).abs() * 2.0;
  } else if (p['leftShoulder'] != null && p['rightShoulder'] != null) {
    span = (p['leftShoulder']!.x - p['rightShoulder']!.x).abs() * 0.4;
  }
  if (span == null || span < 5) span = fallbackSize;

  final eyes = [p['leftEye'], p['rightEye']].whereType<PosePoint>().toList();
  final double eyeY = eyes.isNotEmpty
      ? eyes.map((e) => e.y).reduce((a, b) => a + b) / eyes.length
      : (p['nose']?.y ?? face.first.y);

  final double w = span * headWidthScale;
  final double h = w * headHeightScale;
  return Rect.fromLTWH(cx - w / 2, eyeY - h * headUpRatio, w, h);
}

// 손(안전장갑) 자리 — side: 'left' / 'right'
Rect? _handRect(Map<String, PosePoint> p, String side) {
  final wrist = p['${side}Wrist'];
  if (wrist == null) return null;
  final pts = [
    wrist,
    p['${side}Pinky'],
    p['${side}Index'],
    p['${side}Thumb'],
  ].whereType<PosePoint>().toList();

  final double cx = pts.map((e) => e.x).reduce((a, b) => a + b) / pts.length;
  final double cy = pts.map((e) => e.y).reduce((a, b) => a + b) / pts.length;

  final elbow = p['${side}Elbow'];
  final double size = elbow != null
      ? max(_dist(elbow, wrist) * handSizeScale, 15.0)
      : fallbackSize;
  return Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
}

// 발(안전화) 자리
Rect? _footRect(Map<String, PosePoint> p, String side) {
  final ankle = p['${side}Ankle'];
  if (ankle == null) return null;
  final pts = [
    ankle,
    p['${side}Heel'],
    p['${side}FootIndex'],
  ].whereType<PosePoint>().toList();

  final double minX = pts.map((e) => e.x).reduce(min);
  final double maxX = pts.map((e) => e.x).reduce(max);
  final double minY = pts.map((e) => e.y).reduce(min);
  final double maxY = pts.map((e) => e.y).reduce(max);

  final knee = p['${side}Knee'];
  final double base = knee != null
      ? max(_dist(knee, ankle) * footSizeScale, 15.0)
      : fallbackSize;

  final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  return Rect.fromCenter(
    center: center,
    width: max(maxX - minX, base),
    height: max(maxY - minY, base * 0.8),
  );
}

// 정강이(각반) 자리
Rect? _shinRect(Map<String, PosePoint> p, String side) {
  final knee = p['${side}Knee'];
  final ankle = p['${side}Ankle'];
  if (knee == null || ankle == null) return null;

  final double len = _dist(knee, ankle);
  if (len < 5) return null;
  final double top = ankle.y - len * shinPartRatio;
  final double cx = ankle.x + (knee.x - ankle.x) * shinPartRatio / 2;
  final double w = len * shinWidthScale;
  return Rect.fromLTRB(cx - w / 2, top, cx + w / 2, ankle.y);
}

// 그 부위를 이 보호구 박스가 덮고 있는지 (박스를 조금 넓혀서 부위 중심이 들어가는지)
bool _covered(Rect region, String label, List<Detection> strong) {
  for (final d in strong) {
    if (d.label != label) continue;
    final box = Rect.fromLTWH(d.left, d.top, d.width, d.height);
    final m = max(box.width, box.height) * coverMargin;
    if (box.inflate(m).contains(region.center)) return true;
  }
  return false;
}

// 미착용 빨간 박스 목록 계산
// - checkLabels: 확인할 보호구 (게이트 = 공통 4종)
// - presentLabels: 착용으로 보는 라벨 (인정된 것 + 이번 프레임 강한 감지)
// - currentStrong: 이번 프레임 강한 감지 (한쪽만 빠졌는지 확인용)
// - strapMissing: 턱끈 없는 안전모로 판정됨
List<MissingRegion> computeMissingRegions({
  required List<PosePoint> points,
  required List<String> checkLabels,
  required Set<String> presentLabels,
  required List<Detection> currentStrong,
  bool strapMissing = false,
}) {
  final p = _visible(points, poseMinLikelihood);
  final currentLabels = currentStrong.map((d) => d.label).toSet();
  final out = <MissingRegion>[];

  for (final label in checkLabels) {
    final String name = missingNameKo[label] ?? label;

    // 머리: 양쪽 구분 없음
    if (label == 'helmet') {
      final r = _headRect(p);
      if (r == null) continue;
      if (strapMissing) {
        out.add(MissingRegion('안전모 턱끈 미착용', r));
      } else if (!presentLabels.contains('helmet')) {
        out.add(MissingRegion('$name 미착용', r));
      }
      continue;
    }

    // 손·발·정강이: 왼쪽/오른쪽 따로
    for (final side in const ['left', 'right']) {
      Rect? r;
      if (label == 'safety_gloves') {
        r = _handRect(p, side);
      } else if (label == 'safety_shoes') {
        r = _footRect(p, side);
      } else if (label == 'gaiters') {
        r = _shinRect(p, side);
      }
      if (r == null) continue; // 그 부위가 화면에 안 보이면 그리지 않음

      // ① 아예 없음 → 보이는 쪽 전부 빨강
      final bool missingAll = !presentLabels.contains(label);
      // ② 이번 프레임에 한쪽에만 있음 → 없는 쪽만 빨강
      final bool missingThisSide =
          currentLabels.contains(label) && !_covered(r, label, currentStrong);

      if (missingAll || missingThisSide) {
        out.add(MissingRegion('$name 미착용', r));
      }
    }
  }
  return out;
}

// ─────────────────────────────────────────────
// 화면 그리기
// ─────────────────────────────────────────────

// 미착용 빨간 박스 (라벨은 박스 안쪽 위에 → 초록 라벨(박스 위)과 덜 겹치게)
List<Widget> buildMissingBoxes({
  required BoxConstraints constraints,
  required List<MissingRegion> regions,
  required int imgW,
  required int imgH,
}) {
  if (imgW == 0 || imgH == 0 || regions.isEmpty) return [];

  final double areaW = constraints.maxWidth;
  final double areaH = constraints.maxHeight;
  final double scale = min(areaW / imgW, areaH / imgH);
  final double offsetX = (areaW - imgW * scale) / 2;
  final double offsetY = (areaH - imgH * scale) / 2;

  const red = Color(0xFFE24B4A);
  return regions.map((r) {
    return Positioned(
      left: offsetX + r.rect.left * scale,
      top: offsetY + r.rect.top * scale,
      child: Container(
        width: r.rect.width * scale,
        height: r.rect.height * scale,
        decoration: BoxDecoration(border: Border.all(color: red, width: 2.5)),
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          color: red,
          child: Text(
            r.text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: const TextStyle(fontSize: 9, color: Colors.white),
          ),
        ),
      ),
    );
  }).toList();
}

// ── 확인용: 자세 인식 점을 화면에 노란 점으로 표시 ──
List<Widget> buildPoseDots({
  required BoxConstraints constraints,
  required List<PosePoint> points,
  required int imgW,
  required int imgH,
}) {
  if (imgW == 0 || imgH == 0 || points.isEmpty) return [];

  final double areaW = constraints.maxWidth;
  final double areaH = constraints.maxHeight;
  final double scale = min(areaW / imgW, areaH / imgH);
  final double offsetX = (areaW - imgW * scale) / 2;
  final double offsetY = (areaH - imgH * scale) / 2;

  const double r = 4; // 점 반지름
  return points.where((p) => p.likelihood >= poseMinLikelihood).map((p) {
    return Positioned(
      left: offsetX + p.x * scale - r,
      top: offsetY + p.y * scale - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          color: Colors.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1),
        ),
      ),
    );
  }).toList();
}
