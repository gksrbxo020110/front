import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'ppe_detector.dart';
import 'ppe_labels.dart';
import 'ppe_realtime_filter.dart';

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

  static FrameData fromCameraImage(CameraImage frame, int rotation) {
    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    // iOS는 2 plane (Y + 통합 UV), 안드로이드는 3 plane (Y·U·V 따로)
    final bool twoPlane = frame.planes.length < 3;
    final vPlane = twoPlane ? frame.planes[1] : frame.planes[2];

    // iOS 통합 UV는 U,V가 한 바이트씩 번갈아 있음 → stride를 2로 강제해야 색이 나옴
    // (bytesPerPixel이 null로 와서 1이 되면 색이 깨져 흑백이 됨)
    final int uvPixel = twoPlane ? 2 : (uPlane.bytesPerPixel ?? 1);

    // iOS는 sensorOrientation이 0으로 와서 회전이 안 걸림 → 90도 강제 (안드로이드는 그대로)
    final int rot = Platform.isIOS ? 0 : rotation;

    return FrameData(
      width: frame.width,
      height: frame.height,
      y: Uint8List.fromList(yPlane.bytes),
      u: Uint8List.fromList(uPlane.bytes),
      v: Uint8List.fromList(vPlane.bytes),
      yRowStride: yPlane.bytesPerRow,
      uvRowStride: uPlane.bytesPerRow,
      uvPixelStride: uvPixel,
      rotation: rot,
    );
  }
}

img.Image convertYuvToImage(FrameData f) {
  final int width = f.width;
  final int height = f.height;

  final out = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    final int yRow = y * f.yRowStride;
    final int uvRow = (y >> 1) * f.uvRowStride;
    for (int x = 0; x < width; x++) {
      final int yIndex = yRow + x;
      final int uvIndex = uvRow + (x >> 1) * f.uvPixelStride;

      if (yIndex >= f.y.length || uvIndex >= f.u.length) continue;

      final int yVal = f.y[yIndex];
      final int uVal = f.u[uvIndex];
      final int vIndex = f.uvPixelStride >= 2 ? uvIndex + 1 : uvIndex;
      final int vVal = (vIndex < f.v.length) ? f.v[vIndex] : 128;

      int r = (yVal + 1.402 * (vVal - 128)).round();
      int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
          .round();
      int b = (yVal + 1.772 * (uVal - 128)).round();
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

      out.setPixelRgb(x, y, r, g, b);
    }
  }

  final int rot = ((f.rotation % 360) + 360) % 360;
  if (rot == 90) return img.copyRotate(out, angle: 90);
  if (rot == 180) return img.copyRotate(out, angle: 180);
  if (rot == 270) return img.copyRotate(out, angle: 270);
  return out;
}

const double _burnFontSize = 14;

class TextBitmap {
  final int width;
  final int height;
  final Uint8List alpha;
  TextBitmap(this.width, this.height, this.alpha);
}

class BurnBox {
  final String label;
  final double conf;
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final TextBitmap? text;
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

  static Future<BurnData> fromDetectionsKo(
    img.Image image,
    List<Detection> dets,
  ) async {
    final Map<String, TextBitmap> cache = {};
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

Future<TextBitmap> _renderText(String text) async {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: _burnFontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white,
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

class _LabelRect {
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  const _LabelRect(this.x1, this.y1, this.x2, this.y2);

  bool overlaps(_LabelRect o) =>
      x1 < o.x2 && o.x1 < x2 && y1 < o.y2 && o.y1 < y2;

  bool insideImage(int w, int h) => x1 >= 0 && y1 >= 0 && x2 <= w && y2 <= h;

  int overlapArea(_LabelRect o) {
    final int w = min(x2, o.x2) - max(x1, o.x1);
    final int h = min(y2, o.y2) - max(y1, o.y1);
    if (w <= 0 || h <= 0) return 0;
    return w * h;
  }
}

const int _burnCharW = 8;
const int _burnPadW = 6;
const int _burnLabelH = 18;
const int _burnGap = 3;
const int _burnThickness = 2;

class _Cand {
  final _LabelRect r;
  final bool leader;
  const _Cand(this.r, this.leader);
}

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

  final int sideX = leftSide ? b.x1 - _burnGap - lw : b.x2 + _burnGap;
  for (final k in shifts) {
    final int y = b.y1 + k * step;
    list.add(_Cand(_LabelRect(sideX, y, sideX + lw, y + lh), k != 0));
  }

  final int farX = leftSide ? clusterL - _burnGap - lw : clusterR + _burnGap;
  if (farX != sideX) {
    for (final k in shifts) {
      final int y = b.y1 + k * step;
      list.add(_Cand(_LabelRect(farX, y, farX + lw, y + lh), true));
    }
  }

  list.add(_Cand(_LabelRect(b.x1, b.y1 - lh, b.x1 + lw, b.y1), false));
  list.add(_Cand(_LabelRect(b.x1, b.y2, b.x1 + lw, b.y2 + lh), false));

  final int oppX = leftSide ? b.x2 + _burnGap : b.x1 - _burnGap - lw;
  for (final k in shifts) {
    final int y = b.y1 + k * step;
    list.add(_Cand(_LabelRect(oppX, y, oppX + lw, y + lh), k != 0));
  }

  list.add(_Cand(_LabelRect(b.x1, b.y1, b.x1 + lw, b.y1 + lh), false));
  return list;
}

Uint8List drawBoxesAndEncode(BurnData d) {
  final out = img.Image.from(d.image);
  final green = img.ColorRgb8(95, 187, 70);
  final yellow = img.ColorRgb8(245, 190, 40);
  final white = img.ColorRgb8(255, 255, 255);
  final dark = img.ColorRgb8(26, 26, 26);
  final int w = out.width;
  final int h = out.height;

  final boxes = [...d.boxes]..sort((a, b) => b.conf.compareTo(a.conf));
  if (boxes.isEmpty) return img.encodeJpg(out, quality: 85);

  final List<_LabelRect> boxRects = boxes
      .map((b) => _LabelRect(b.x1, b.y1, b.x2, b.y2))
      .toList();

  double sumCx = 0;
  int clusterL = w;
  int clusterR = 0;
  for (final b in boxes) {
    sumCx += (b.x1 + b.x2) / 2;
    clusterL = min(clusterL, b.x1);
    clusterR = max(clusterR, b.x2);
  }
  final double bodyCx = sumCx / boxes.length;

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

  final List<_LabelRect> placed = [];
  for (final b in boxes) {
    final bool strong = b.conf >= PpeRealtimeFilter.minConfidence;
    final color = strong ? green : yellow;
    final text = b.label;
    final TextBitmap? tb = b.text;
    final int lw = tb != null
        ? tb.width + _burnPadW
        : text.length * _burnCharW + _burnPadW;
    final int lh = tb != null ? max(_burnLabelH, tb.height + 4) : _burnLabelH;
    final bool leftSide = (b.x1 + b.x2) / 2 < bodyCx;
    final ownBox = _LabelRect(b.x1, b.y1, b.x2, b.y2);

    final cands = _labelCandidates(b, lw, lh, leftSide, clusterL, clusterR);

    int coverOf(_LabelRect r) {
      int sum = 0;
      for (final br in boxRects) {
        sum += r.overlapArea(br);
      }
      return sum;
    }

    _Cand? chosen;
    for (final c in cands) {
      if (!c.r.insideImage(w, h)) continue;
      if (placed.any((p) => p.overlaps(c.r))) continue;
      if (coverOf(c.r) > 0) continue;
      chosen = c;
      break;
    }
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
    if (chosen == null) {
      final int x = b.x1.clamp(0, max(0, w - lw));
      final int y = (b.y1 - lh).clamp(0, max(0, h - lh));
      chosen = _Cand(_LabelRect(x, y, x + lw, y + lh), false);
    }
    final r = chosen.r;
    placed.add(r);

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
