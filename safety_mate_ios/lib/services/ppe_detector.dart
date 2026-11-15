import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'ppe_labels.dart';

// 감지 결과 하나
class Detection {
  final int classIndex;
  final String label;
  final double confidence;
  final List<double> box; // [cx, cy, w, h] (0~1 정규화)

  Detection({
    required this.classIndex,
    required this.label,
    required this.confidence,
    required this.box,
  });

  String get koreanName => PpeLabels.koreanNames[label] ?? label;
}

class PpeDetector {
  Interpreter? _interpreter;
  bool get isReady => _interpreter != null;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/best.tflite');
      print('✅ 모델 로드 성공');
      print('입력: ${_interpreter!.getInputTensor(0).shape}');
      print('출력: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('❌ 모델 로드 실패: $e');
    }
  }

  // 감지 실행
  // input: [1][3][640][640] 형태 (채널 우선, 0~1 정규화)
  List<Detection> detect(List input) {
    if (_interpreter == null) {
      print('모델이 로드되지 않음');
      return [];
    }

    try {
      // 출력 버퍼: [1, 20, 8400]
      final output = List.generate(
        1,
        (_) => List.generate(20, (_) => List.filled(8400, 0.0)),
      );

      _interpreter!.run(input, output);

      return _parseOutput(output[0]);
    } catch (e) {
      print('감지 실패: $e');
      return [];
    }
  }

  // 출력 파싱: [20][8400] → Detection 목록
  // 20 = 4(cx,cy,w,h) + 16(클래스 확률)
  List<Detection> _parseOutput(List<List<double>> output) {
    final detections = <Detection>[];
    const numClasses = 16;
    const numBoxes = 8400;

    for (int i = 0; i < numBoxes; i++) {
      // 이 후보의 클래스별 확률 중 최대값 찾기
      double maxScore = 0;
      int maxClass = -1;
      for (int c = 0; c < numClasses; c++) {
        final score = output[4 + c][i]; // 4번째부터 클래스 확률
        if (score > maxScore) {
          maxScore = score;
          maxClass = c;
        }
      }

      // 임계값 넘는 것만
      if (maxScore >= PpeLabels.confThreshold && maxClass >= 0) {
        final cx = output[0][i];
        final cy = output[1][i];
        final w = output[2][i];
        final h = output[3][i];
        detections.add(
          Detection(
            classIndex: maxClass,
            label: PpeLabels.labelAt(maxClass),
            confidence: maxScore,
            box: [cx, cy, w, h],
          ),
        );
      }
    }

    // NMS (겹치는 박스 제거)
    return _nms(detections);
  }

  List<Detection> _nms(List<Detection> dets, {double iouThreshold = 0.45}) {
    if (dets.isEmpty) return [];

    // 신뢰도 높은 순 정렬
    // 단, helmet_nostrap(끈 풀림)은 안전 우선이라 정렬에서 먼저 오게 가산점
    dets.sort((a, b) {
      final aScore = a.label == 'helmet_nostrap'
          ? a.confidence + 1.0
          : a.confidence;
      final bScore = b.label == 'helmet_nostrap'
          ? b.confidence + 1.0
          : b.confidence;
      return bScore.compareTo(aScore);
    });

    final result = <Detection>[];
    final removed = List.filled(dets.length, false);

    for (int i = 0; i < dets.length; i++) {
      if (removed[i]) continue;
      result.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (removed[j]) continue;
        if (_iou(dets[i].box, dets[j].box) > iouThreshold) {
          removed[j] = true;
        }
      }
    }

    // 안전모 끈 풀림 우선: helmet과 helmet_nostrap이 같은 위치에 겹치면
    // 신뢰도와 무관하게 nostrap(미착용)을 남기고 helmet을 제거
    final hasNostrap = result.any((d) => d.label == 'helmet_nostrap');
    if (hasNostrap) {
      result.removeWhere((d) {
        if (d.label != 'helmet') return false;
        // 이 helmet이 어떤 nostrap과 겹치면 제거
        return result.any(
          (n) => n.label == 'helmet_nostrap' && _iou(d.box, n.box) > 0.3,
        );
      });
    }

    return result;
  }

  // 두 박스의 겹침 비율 (IoU)
  double _iou(List<double> a, List<double> b) {
    // [cx, cy, w, h] → [x1, y1, x2, y2]
    final ax1 = a[0] - a[2] / 2, ay1 = a[1] - a[3] / 2;
    final ax2 = a[0] + a[2] / 2, ay2 = a[1] + a[3] / 2;
    final bx1 = b[0] - b[2] / 2, by1 = b[1] - b[3] / 2;
    final bx2 = b[0] + b[2] / 2, by2 = b[1] + b[3] / 2;

    final ix1 = math.max(ax1, bx1);
    final iy1 = math.max(ay1, by1);
    final ix2 = math.min(ax2, bx2);
    final iy2 = math.min(ay2, by2);

    final iw = math.max(0.0, ix2 - ix1);
    final ih = math.max(0.0, iy2 - iy1);
    final inter = iw * ih;

    final areaA = a[2] * a[3];
    final areaB = b[2] * b[3];
    final union = areaA + areaB - inter;

    return union > 0 ? inter / union : 0;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

// 캡처 이미지에 감지 박스 그리기 (저장/전송용)
// image: RGB 이미지, detections: 감지 결과(0~1 정규화 box)
// 색: 60%↑ 초록 / 40~59% 노랑. 라벨 영어(한글 폰트 미지원), 겹침 회피
img.Image drawDetectionsOnImage(img.Image image, List<Detection> detections) {
  final w = image.width;
  final h = image.height;

  // 이미 놓인 라벨 영역들 (겹침 회피용): [x1, y1, x2, y2]
  final placedLabels = <List<int>>[];

  // 두 사각형이 겹치는지
  bool overlaps(List<int> a, List<int> b) {
    return a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1];
  }

  for (final d in detections) {
    // 신뢰도로 색 결정: 60%↑ 초록, 40~59% 노랑
    final bool high = d.confidence >= 0.6;
    final boxColor = high
        ? img.ColorRgb8(0, 230, 118) // 초록
        : img.ColorRgb8(255, 193, 7); // 노랑

    // box = [cx, cy, w, h] 0~1 정규화 → 이미지 픽셀로
    final cx = d.box[0] * w;
    final cy = d.box[1] * h;
    final bw = d.box[2] * w;
    final bh = d.box[3] * h;

    final x1 = (cx - bw / 2).round().clamp(0, w - 1);
    final y1 = (cy - bh / 2).round().clamp(0, h - 1);
    final x2 = (cx + bw / 2).round().clamp(0, w - 1);
    final y2 = (cy + bh / 2).round().clamp(0, h - 1);

    // 박스 (얇게 두께 2)
    img.drawRect(
      image,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: boxColor,
      thickness: 2,
    );

    // 라벨 (영어 이름만, % 제거)
    final label = d.label;
    final labelW = label.length * 8 + 4;
    const labelH = 14;

    // 라벨 위치: 박스 안쪽 위에서 시작, 겹치면 아래로 밀기
    int lx = x1;
    int ly = y1 + 1;
    if (lx + labelW > w) lx = (w - labelW).clamp(0, w - 1);

    int tries = 0;
    while (tries < 10) {
      final rect = [lx, ly, lx + labelW, ly + labelH];
      final hasOverlap = placedLabels.any((p) => overlaps(rect, p));
      if (!hasOverlap) break;
      ly += labelH + 2; // 아래로 밀기
      if (ly + labelH > h) {
        ly = (y1 - labelH - 1).clamp(0, h - 1);
        break;
      }
      tries++;
    }

    placedLabels.add([lx, ly, lx + labelW, ly + labelH]);

    // 라벨 배경 + 텍스트
    img.fillRect(
      image,
      x1: lx,
      y1: ly,
      x2: (lx + labelW).clamp(0, w - 1),
      y2: (ly + labelH).clamp(0, h - 1),
      color: boxColor,
    );
    img.drawString(
      image,
      label,
      font: img.arial14,
      x: lx + 2,
      y: ly,
      color: img.ColorRgb8(0, 0, 0), // 검정 글씨
    );
  }

  return image;
}
