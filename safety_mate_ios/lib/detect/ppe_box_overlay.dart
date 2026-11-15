import 'dart:math';
import 'package:flutter/material.dart';
import 'ppe_detector.dart';
import 'ppe_labels.dart';
import 'ppe_realtime_filter.dart';

// ─────────────────────────────────────────────
// 실시간 감지 박스 + 라벨 그리기 (게이트·Inspection 공통)
// ─────────────────────────────────────────────

const Color boxGreen = Color(0xFF5FBB46);
const Color boxYellow = Color(0xFFF5BE28);

const double _boxBorder = 1.5;
const TextStyle _labelStyleOnGreen = TextStyle(
  fontSize: 9,
  color: Colors.white,
);
const TextStyle _labelStyleOnYellow = TextStyle(
  fontSize: 9,
  color: Color(0xFF1A1A1A),
);
const double _labelPadH = 5;
const double _labelPadV = 1;
const double _labelGap = 3;

double _overlapArea(Rect a, Rect b) {
  final double w = min(a.right, b.right) - max(a.left, b.left);
  final double h = min(a.bottom, b.bottom) - max(a.top, b.top);
  if (w <= 0 || h <= 0) return 0;
  return w * h;
}

class _Cand {
  final Rect r;
  final bool leader;
  const _Cand(this.r, this.leader);
}

List<_Cand> _labelCandidates(
  Rect b,
  double lw,
  double lh,
  bool leftSide,
  double clusterL,
  double clusterR,
) {
  final List<_Cand> list = [];
  final double step = lh + 1;
  const List<int> shifts = [0, 1, -1, 2, -2, 3, -3, 4, -4];

  final double sideX = leftSide ? b.left - _labelGap - lw : b.right + _labelGap;
  for (final k in shifts) {
    list.add(_Cand(Rect.fromLTWH(sideX, b.top + k * step, lw, lh), k != 0));
  }

  final double farX = leftSide
      ? clusterL - _labelGap - lw
      : clusterR + _labelGap;
  if ((farX - sideX).abs() > 0.5) {
    for (final k in shifts) {
      list.add(_Cand(Rect.fromLTWH(farX, b.top + k * step, lw, lh), true));
    }
  }

  list.add(_Cand(Rect.fromLTWH(b.left, b.top - lh, lw, lh), false));
  list.add(_Cand(Rect.fromLTWH(b.left, b.bottom, lw, lh), false));

  final double oppX = leftSide ? b.right + _labelGap : b.left - _labelGap - lw;
  for (final k in shifts) {
    list.add(_Cand(Rect.fromLTWH(oppX, b.top + k * step, lw, lh), k != 0));
  }

  list.add(_Cand(Rect.fromLTWH(b.left, b.top, lw, lh), false));
  return list;
}

class _Leader {
  final Offset from;
  final Offset to;
  final Color color;
  const _Leader(this.from, this.to, this.color);
}

class _LeaderPainter extends CustomPainter {
  final List<_Leader> lines;
  _LeaderPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final paint = Paint()
        ..color = l.color
        ..strokeWidth = 1;
      canvas.drawLine(l.from, l.to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeaderPainter oldDelegate) => true;
}

class _ShownBox {
  final Detection d;
  final Rect box;
  final bool strong;
  const _ShownBox(this.d, this.box, this.strong);
}

List<Widget> buildDetectionBoxes({
  required BoxConstraints constraints,
  required List<Detection> detections,
  required int imgW,
  required int imgH,
  bool mirror = false,
}) {
  if (imgW == 0 || imgH == 0) return [];

  final double areaW = constraints.maxWidth;
  final double areaH = constraints.maxHeight;
  final double scale = min(areaW / imgW, areaH / imgH);
  final double offsetX = (areaW - imgW * scale) / 2;
  final double offsetY = (areaH - imgH * scale) / 2;

  final visible = detections.where(PpeRealtimeFilter.isVisible).toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  if (visible.isEmpty) return [];

  final List<_ShownBox> shown = visible.map((d) {
    final double dispLeft = mirror ? (imgW - d.left - d.width) : d.left;
    final Rect box = Rect.fromLTWH(
      offsetX + dispLeft * scale,
      offsetY + d.top * scale,
      d.width * scale,
      d.height * scale,
    );
    return _ShownBox(d, box, PpeRealtimeFilter.isStrong(d));
  }).toList();

  final List<Rect> boxRects = shown.map((s) => s.box).toList();

  double sumCx = 0;
  double clusterL = areaW;
  double clusterR = 0;
  for (final r in boxRects) {
    sumCx += r.center.dx;
    clusterL = min(clusterL, r.left);
    clusterR = max(clusterR, r.right);
  }
  final double bodyCx = sumCx / boxRects.length;

  final List<Widget> boxWidgets = [];
  final List<Widget> labelWidgets = [];
  final List<Rect> placedLabels = [];
  final List<_Leader> leaders = [];

  double coverOf(Rect r) {
    double sum = 0;
    for (final br in boxRects) {
      sum += _overlapArea(r, br);
    }
    return sum;
  }

  bool insideArea(Rect r) =>
      r.left >= 0 && r.top >= 0 && r.right <= areaW && r.bottom <= areaH;

  for (final s in shown) {
    final Rect box = s.box;
    final Color color = s.strong ? boxGreen : boxYellow;
    final TextStyle style = s.strong ? _labelStyleOnGreen : _labelStyleOnYellow;

    boxWidgets.add(
      Positioned(
        left: box.left,
        top: box.top,
        child: Container(
          width: box.width,
          height: box.height,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: _boxBorder),
          ),
        ),
      ),
    );

    final String text = ppeLabelsKo[s.d.label] ?? s.d.label;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double lw = tp.width + _labelPadH * 2;
    final double lh = tp.height + _labelPadV * 2;

    final bool leftSide = box.center.dx < bodyCx;
    final cands = _labelCandidates(box, lw, lh, leftSide, clusterL, clusterR);

    _Cand? chosen;
    for (final c in cands) {
      if (!insideArea(c.r)) continue;
      if (placedLabels.any((p) => p.overlaps(c.r))) continue;
      if (coverOf(c.r) > 0) continue;
      chosen = c;
      break;
    }
    if (chosen == null) {
      double best = double.infinity;
      for (final c in cands) {
        if (!insideArea(c.r)) continue;
        if (placedLabels.any((p) => p.overlaps(c.r))) continue;
        final double cover = coverOf(c.r);
        if (cover < best) {
          best = cover;
          chosen = c;
        }
      }
    }
    chosen ??= _Cand(
      Rect.fromLTWH(
        box.left.clamp(0.0, max(0.0, areaW - lw)),
        (box.top - lh).clamp(0.0, max(0.0, areaH - lh)),
        lw,
        lh,
      ),
      false,
    );
    final Rect r = chosen.r;
    placedLabels.add(r);

    if (chosen.leader && !r.overlaps(box)) {
      final double ly = r.center.dy;
      final bool labelLeft = r.right <= box.left;
      final bool labelRight = r.left >= box.right;
      if (labelLeft || labelRight) {
        final double fromX = labelLeft ? r.right : r.left;
        final double toX = labelLeft ? box.left : box.right;
        final double toY = ly.clamp(box.top, box.bottom);
        leaders.add(_Leader(Offset(fromX, ly), Offset(toX, toY), color));
      }
    }

    labelWidgets.add(
      Positioned(
        left: r.left,
        top: r.top,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _labelPadH,
            vertical: _labelPadV,
          ),
          color: color,
          child: Text(text, style: style, maxLines: 1),
        ),
      ),
    );
  }

  return [
    ...boxWidgets,
    if (leaders.isNotEmpty)
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _LeaderPainter(leaders)),
        ),
      ),
    ...labelWidgets,
  ];
}
