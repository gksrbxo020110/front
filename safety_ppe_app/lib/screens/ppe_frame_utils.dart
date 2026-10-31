import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'ppe_detector.dart';
import 'ppe_labels.dart';
import 'ppe_realtime_filter.dart';

// ─────────────────────────────────────────────
// 실시간 감지 공통 도구 (게이트 · Inspection 공통)
// ─────────────────────────────────────────────

// 카메라 프레임 데이터 (다른 isolate로 넘기기 위한 묶음)
class FrameData {
  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int rotation;

  FrameData({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotation,
  });

  // 카메라 프레임 → FrameData (바이트 복사)
  static FrameData fromCameraImage(CameraImage frame, int rotation) {
    return FrameData(
      width: frame.width,
      height: frame.height,
      y: Uint8List.fromList(frame.planes[0].bytes),
      u: Uint8List.fromList(frame.planes[1].bytes),
      v: Uint8List.fromList(frame.planes[2].bytes),
      yRowStride: frame.planes[0].bytesPerRow,
      uvRowStride: frame.planes[1].bytesPerRow,
      uvPixelStride: frame.planes[1].bytesPerPixel ?? 1,
      rotation: rotation,
    );
  }
}

// YUV420 → RGB 이미지 변환 + 세로로 회전 (compute로 백그라운드 실행)
// 속도 개선: 픽셀마다 setPixelRgb + 마지막에 copyRotate(통째 복사)
//   → 바이트 배열에 직접 쓰고, 회전도 변환하면서 바로 처리 (정수 계산)
// 회전 방향은 기존 img.copyRotate와 동일 (90 = 시계 방향)
img.Image convertYuvToImage(FrameData f) {
  final int w = f.width;
  final int h = f.height;
  final int rot = ((f.rotation % 360) + 360) % 360;

  // 회전 후 크기
  final bool swap = rot == 90 || rot == 270;
  final int outW = swap ? h : w;
  final int outH = swap ? w : h;
  final Uint8List buf = Uint8List(outW * outH * 3);

  final Uint8List yP = f.y;
  final Uint8List uP = f.u;
  final Uint8List vP = f.v;
  final int yLen = yP.length;
  final int uLen = uP.length;
  final int vLen = vP.length;

  for (int row = 0; row < h; row++) {
    final int yRow = row * f.yRowStride;
    final int uvRow = (row >> 1) * f.uvRowStride;

    for (int col = 0; col < w; col++) {
      final int yIndex = yRow + col;
      final int uvIndex = uvRow + (col >> 1) * f.uvPixelStride;
      if (yIndex >= yLen || uvIndex >= uLen || uvIndex >= vLen) {
        continue;
      }

      final int yv = yP[yIndex] << 10; // ×1024 (정수 계산)
      final int u = uP[uvIndex] - 128;
      final int v = vP[uvIndex] - 128;

      // 기존 계수(1.402 / 0.344136 / 0.714136 / 1.772) × 1024
      int r = (yv + 1436 * v) >> 10;
      int g = (yv - 352 * u - 731 * v) >> 10;
      int b = (yv + 1815 * u) >> 10;
      if (r < 0) {
        r = 0;
      } else if (r > 255) {
        r = 255;
      }
      if (g < 0) {
        g = 0;
      } else if (g > 255) {
        g = 255;
      }
      if (b < 0) {
        b = 0;
      } else if (b > 255) {
        b = 255;
      }

      // 회전된 위치 계산 (img.copyRotate와 같은 방향)
      int dx, dy;
      switch (rot) {
        case 90:
          dx = h - 1 - row;
          dy = col;
          break;
        case 180:
          dx = w - 1 - col;
          dy = h - 1 - row;
          break;
        case 270:
          dx = row;
          dy = w - 1 - col;
          break;
        default:
          dx = col;
          dy = row;
      }

      final int o = (dy * outW + dx) * 3;
      buf[o] = r;
      buf[o + 1] = g;
      buf[o + 2] = b;
    }
  }

  return img.Image.fromBytes(
    width: outW,
    height: outH,
    bytes: buf.buffer,
    numChannels: 3,
  );
}

// ─────────────────────────────────────────────
// 저장용: 사진에 박스 + 한글 라벨 그려서 JPG로
// 초록(60% 이상) / 노랑(40~59%), 라벨은 이름만 (% 없음)
//
// 한글 라벨 방식 (A안):
//   image 패키지 기본 글꼴(arial14)엔 한글이 없어서,
//   ① 화면 쪽(메인)에서 Flutter로 한글 글자만 작은 그림으로 만들고 (가벼움)
//   ② 백그라운드(compute)에서 박스·라벨 자리 계산 + 글자 그림 합성 + JPG 변환 (무거운 일)
//   → 감지 화면과 같은 폰 기본 한글 글꼴로 나옴
// ─────────────────────────────────────────────

// 저장 사진 라벨 글자 크기(px)
const double _burnFontSize = 14;

// 글자 그림 (다른 isolate로 넘기기 위해 숫자·바이트만)
class TextBitmap {
  final int width;
  final int height;
  final Uint8List alpha; // 글자 모양(투명도)만, 1픽셀 = 1바이트
  TextBitmap(this.width, this.height, this.alpha);
}

class BurnBox {
  final String label;
  final double conf;
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final TextBitmap? text; // 한글 라벨 글자 그림 (없으면 영어로 그림)
  BurnBox(
    this.label,
    this.conf,
    this.x1,
    this.y1,
    this.x2,
    this.y2, [
    this.text,
  ]);
}

class BurnData {
  final img.Image image;
  final List<BurnBox> boxes;
  BurnData(this.image, this.boxes);

  // 감지 결과로 BurnData 만들기 (40% 미만은 제외, 영어 라벨)
  static BurnData fromDetections(img.Image image, List<Detection> dets) {
    return BurnData(
      image,
      dets
          .where(PpeRealtimeFilter.isVisible)
          .map(
            (d) => BurnBox(
              d.label,
              d.confidence,
              d.left.round(),
              d.top.round(),
              (d.left + d.width).round(),
              (d.top + d.height).round(),
            ),
          )
          .toList(),
    );
  }

  // 한글 라벨 버전 (게이트·Inspection 저장에서 사용)
  // 화면 쪽에서 실행해야 함 (Flutter 글자 그리기) → 그 뒤 compute로 넘김
  static Future<BurnData> fromDetectionsKo(
    img.Image image,
    List<Detection> dets,
  ) async {
    final Map<String, TextBitmap> cache = {}; // 같은 라벨은 한 번만 그림
    final List<BurnBox> boxes = [];
    for (final d in dets.where(PpeRealtimeFilter.isVisible)) {
      final String name = ppeLabelsKo[d.label] ?? d.label;
      TextBitmap? tb = cache[name];
      if (tb == null) {
        try {
          tb = await _renderText(name);
          cache[name] = tb;
        } catch (e) {
          debugPrint('라벨 글자 그리기 실패 → 영어로: $e');
        }
      }
      boxes.add(
        BurnBox(
          d.label,
          d.confidence,
          d.left.round(),
          d.top.round(),
          (d.left + d.width).round(),
          (d.top + d.height).round(),
          tb,
        ),
      );
    }
    return BurnData(image, boxes);
  }
}

// 한글 글자 → 투명도 그림 (Flutter로 그림, 폰 기본 한글 글꼴)
Future<TextBitmap> _renderText(String text) async {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: _burnFontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white, // 모양만 쓰고 색은 합성할 때 정함
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  final int w = max(1, tp.width.ceil());
  final int h = max(1, tp.height.ceil());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  tp.paint(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  if (data == null) throw Exception('글자 그림 변환 실패');

  final Uint8List rgba = data.buffer.asUint8List();
  final Uint8List alpha = Uint8List(w * h);
  for (int i = 0; i < w * h; i++) {
    alpha[i] = rgba[i * 4 + 3];
  }
  return TextBitmap(w, h, alpha);
}

// 글자 그림을 사진에 합성 (백그라운드에서 실행)
void _blendText(
  img.Image out,
  TextBitmap t,
  int x0,
  int y0,
  int cr,
  int cg,
  int cb,
) {
  final int w = out.width;
  final int h = out.height;
  for (int y = 0; y < t.height; y++) {
    final int py = y0 + y;
    if (py < 0 || py >= h) continue;
    for (int x = 0; x < t.width; x++) {
      final int a = t.alpha[y * t.width + x];
      if (a == 0) continue;
      final int px = x0 + x;
      if (px < 0 || px >= w) continue;
      final p = out.getPixel(px, py);
      final int ia = 255 - a;
      out.setPixelRgb(
        px,
        py,
        (p.r.toInt() * ia + cr * a) ~/ 255,
        (p.g.toInt() * ia + cg * a) ~/ 255,
        (p.b.toInt() * ia + cb * a) ~/ 255,
      );
    }
  }
}

// 라벨 자리 계산용 사각형 (픽셀 좌표)
class _LabelRect {
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  const _LabelRect(this.x1, this.y1, this.x2, this.y2);

  bool overlaps(_LabelRect o) =>
      x1 < o.x2 && o.x1 < x2 && y1 < o.y2 && o.y1 < y2;

  bool insideImage(int w, int h) => x1 >= 0 && y1 >= 0 && x2 <= w && y2 <= h;

  // 겹치는 넓이 (가리는 정도 비교용)
  int overlapArea(_LabelRect o) {
    final int w = min(x2, o.x2) - max(x1, o.x1);
    final int h = min(y2, o.y2) - max(y1, o.y1);
    if (w <= 0 || h <= 0) return 0;
    return w * h;
  }
}

// 저장 사진 라벨·박스 설정 (영어 arial14 기준, 한글은 글자 그림 크기로 계산)
const int _burnCharW = 8; // 글자 1개 대략 폭(px)
const int _burnPadW = 6; // 라벨 좌우 여백 합(px)
const int _burnLabelH = 18; // 라벨 높이(px) — 실제 글자 높이에 맞춤 (라벨끼리 겹침 방지)
const int _burnGap = 3; // 박스와 라벨 사이 간격(px)
const int _burnThickness = 2; // 박스 두께(px)

// 라벨 후보 자리 (+ 박스와 떨어져 있으면 연결선 필요 여부)
class _Cand {
  final _LabelRect r;
  final bool leader; // 박스와 떨어진 자리 → 가는 연결선 그림
  const _Cand(this.r, this.leader);
}

// 박스 하나의 라벨 후보 자리들 (좋은 순서대로)
//   ① 몸 바깥쪽 옆 (박스 위쪽 높이부터 아래·위로 한 칸씩)
//   ② 박스 무리 전체의 바깥쪽 (연결선)
//   ③ 박스 위 / 아래
//   ④ 반대쪽 옆
//   ⑤ 박스 안쪽 위 (최후)
List<_Cand> _labelCandidates(
  BurnBox b,
  int lw,
  int lh,
  bool leftSide,
  int clusterL,
  int clusterR,
) {
  final List<_Cand> list = [];
  final int step = lh + 1;
  const List<int> shifts = [0, 1, -1, 2, -2, 3, -3, 4, -4];

  // ① 바깥쪽 바로 옆
  final int sideX = leftSide ? b.x1 - _burnGap - lw : b.x2 + _burnGap;
  for (final k in shifts) {
    final int y = b.y1 + k * step;
    list.add(_Cand(_LabelRect(sideX, y, sideX + lw, y + lh), k != 0));
  }

  // ② 박스 무리 바깥쪽 (다른 박스가 바로 옆에 붙어 있을 때)
  final int farX = leftSide ? clusterL - _burnGap - lw : clusterR + _burnGap;
  if (farX != sideX) {
    for (final k in shifts) {
      final int y = b.y1 + k * step;
      list.add(_Cand(_LabelRect(farX, y, farX + lw, y + lh), true));
    }
  }

  // ③ 박스 위 / 아래
  list.add(_Cand(_LabelRect(b.x1, b.y1 - lh, b.x1 + lw, b.y1), false));
  list.add(_Cand(_LabelRect(b.x1, b.y2, b.x1 + lw, b.y2 + lh), false));

  // ④ 반대쪽 옆
  final int oppX = leftSide ? b.x2 + _burnGap : b.x1 - _burnGap - lw;
  for (final k in shifts) {
    final int y = b.y1 + k * step;
    list.add(_Cand(_LabelRect(oppX, y, oppX + lw, y + lh), k != 0));
  }

  // ⑤ 박스 안쪽 위 (장비를 일부 가림 → 최후)
  list.add(_Cand(_LabelRect(b.x1, b.y1, b.x1 + lw, b.y1 + lh), false));
  return list;
}

// compute로 백그라운드 실행
// 라벨 배치 규칙 (실제 장비가 보이도록):
//   - 라벨끼리 안 겹치게 + 라벨이 다른 박스(장비)를 가리지 않게
//   - 몸 중심보다 왼쪽 박스는 왼쪽 바깥, 오른쪽 박스는 오른쪽 바깥에 먼저
//   - 바깥에 자리가 없으면 아래·위로 한 칸씩 비켜서, 그래도 없으면 박스 무리 바깥 + 연결선
//   - 어디에도 완벽한 자리가 없으면 장비를 가장 적게 가리는 자리
Uint8List drawBoxesAndEncode(BurnData d) {
  final out = img.Image.from(d.image);
  final green = img.ColorRgb8(95, 187, 70);
  final yellow = img.ColorRgb8(245, 190, 40);
  final white = img.ColorRgb8(255, 255, 255);
  final dark = img.ColorRgb8(26, 26, 26);
  final int w = out.width;
  final int h = out.height;

  // 신뢰도 높은 순 (좋은 자리를 먼저 차지)
  final boxes = [...d.boxes]..sort((a, b) => b.conf.compareTo(a.conf));
  if (boxes.isEmpty) return img.encodeJpg(out, quality: 85);

  // 박스 영역 (라벨이 가리면 안 되는 곳)
  final List<_LabelRect> boxRects = boxes
      .map((b) => _LabelRect(b.x1, b.y1, b.x2, b.y2))
      .toList();

  // 몸 중심선 = 박스 가운데들의 평균, 박스 무리의 왼쪽·오른쪽 끝
  double sumCx = 0;
  int clusterL = w;
  int clusterR = 0;
  for (final b in boxes) {
    sumCx += (b.x1 + b.x2) / 2;
    clusterL = min(clusterL, b.x1);
    clusterR = max(clusterR, b.x2);
  }
  final double bodyCx = sumCx / boxes.length;

  // 1) 박스 먼저 전부 그리기
  for (final b in boxes) {
    final bool strong = b.conf >= PpeRealtimeFilter.minConfidence;
    img.drawRect(
      out,
      x1: b.x1,
      y1: b.y1,
      x2: b.x2,
      y2: b.y2,
      color: strong ? green : yellow,
      thickness: _burnThickness,
    );
  }

  // 2) 라벨 자리 찾아서 그리기
  final List<_LabelRect> placed = [];
  for (final b in boxes) {
    final bool strong = b.conf >= PpeRealtimeFilter.minConfidence;
    final color = strong ? green : yellow;
    final text = b.label; // 영어 이름 (한글 글자 그림 없을 때만 사용)
    final TextBitmap? tb = b.text;
    final int lw = tb != null
        ? tb.width + _burnPadW
        : text.length * _burnCharW + _burnPadW;
    final int lh = tb != null ? max(_burnLabelH, tb.height + 4) : _burnLabelH;
    final bool leftSide = (b.x1 + b.x2) / 2 < bodyCx;
    final ownBox = _LabelRect(b.x1, b.y1, b.x2, b.y2);

    final cands = _labelCandidates(b, lw, lh, leftSide, clusterL, clusterR);

    // 이 라벨이 가리는 장비 넓이 (자기 박스 포함)
    int coverOf(_LabelRect r) {
      int sum = 0;
      for (final br in boxRects) {
        sum += r.overlapArea(br);
      }
      return sum;
    }

    _Cand? chosen;
    // 1차: 사진 안 + 라벨 안 겹침 + 장비(박스) 하나도 안 가림
    for (final c in cands) {
      if (!c.r.insideImage(w, h)) continue;
      if (placed.any((p) => p.overlaps(c.r))) continue;
      if (coverOf(c.r) > 0) continue;
      chosen = c;
      break;
    }
    // 2차: 사진 안 + 라벨 안 겹침 중에서 장비를 가장 적게 가리는 자리
    if (chosen == null) {
      int best = 1 << 30;
      for (final c in cands) {
        if (!c.r.insideImage(w, h)) continue;
        if (placed.any((p) => p.overlaps(c.r))) continue;
        final int cover = coverOf(c.r);
        if (cover < best) {
          best = cover;
          chosen = c;
        }
      }
    }
    // 3차: 빈자리가 전혀 없으면 → 박스 위에 두되 사진 안으로 맞춤
    if (chosen == null) {
      final int x = b.x1.clamp(0, max(0, w - lw));
      final int y = (b.y1 - lh).clamp(0, max(0, h - lh));
      chosen = _Cand(_LabelRect(x, y, x + lw, y + lh), false);
    }
    final r = chosen.r;
    placed.add(r);

    // 박스와 떨어진 라벨이면 가는 연결선 (어느 박스 라벨인지 보이게)
    if (chosen.leader && !r.overlaps(ownBox)) {
      final int ly = (r.y1 + r.y2) ~/ 2;
      final bool labelLeft = r.x2 <= b.x1;
      final bool labelRight = r.x1 >= b.x2;
      if (labelLeft || labelRight) {
        final int fromX = labelLeft ? r.x2 : r.x1;
        final int toX = labelLeft ? b.x1 : b.x2;
        final int toY = ly.clamp(b.y1, b.y2);
        img.drawLine(
          out,
          x1: fromX,
          y1: ly,
          x2: toX,
          y2: toY,
          color: color,
          thickness: 1,
        );
      }
    }

    img.fillRect(
      out,
      x1: r.x1,
      y1: r.y1,
      x2: min(w - 1, r.x2),
      y2: min(h - 1, r.y2),
      color: color,
    );
    if (tb != null) {
      // 한글 라벨 (초록 위 흰 글자 / 노랑 위 검은 글자)
      _blendText(
        out,
        tb,
        r.x1 + 3,
        r.y1 + ((r.y2 - r.y1) - tb.height) ~/ 2,
        strong ? 255 : 26,
        strong ? 255 : 26,
        strong ? 255 : 26,
      );
    } else {
      img.drawString(
        out,
        text,
        font: img.arial14,
        x: r.x1 + 3,
        y: r.y1 + 2,
        color: strong ? white : dark,
      );
    }
  }

  return img.encodeJpg(out, quality: 85);
}
