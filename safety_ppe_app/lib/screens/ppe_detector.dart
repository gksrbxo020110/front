import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ppe_labels.dart';

class Detection {
  final String label;
  final double confidence;
  // 박스 좌표 (원본 이미지 픽셀 기준)
  final double left;
  final double top;
  final double width;
  final double height;
  Detection(
    this.label,
    this.confidence,
    this.left,
    this.top,
    this.width,
    this.height,
  );
}

class PpeDetector {
  Interpreter? _interpreter;

  static const int inputSize = 640;
  static const int numClasses = 16;
  static const double defaultThreshold = 0.30;
  static const double iouThreshold = 0.45; // NMS 겹침 기준

  // 서로 헷갈리는 장비 묶음: 같은 자리에서 겹치면 신뢰도 높은 것 하나만 남김
  // (예: 안전모 + 안전모(턱끈X)가 한 머리에 같이 뜨는 경우)
  static const List<Set<String>> confusableGroups = [
    {'helmet', 'helmet_nostrap'},
    {'gaiters', 'welding_gaiters'},
  ];
  static const double confusableOverlap = 0.5; // 작은 박스 기준 겹침 비율

  // ★ 속도 설정
  static const int numThreads = 4; // TFLite가 쓰는 CPU 개수 (기본 1 → 4)
  static const bool printDetections = false; // 프레임마다 감지 목록 출력 (확인용)

  // 0~255 → 0~1 변환표 (매번 나눗셈 안 하게)
  static final Float32List _norm = Float32List.fromList(
    List<double>.generate(256, (i) => i / 255.0),
  );

  // 입력을 바이트 그대로 넘길 수 있는지 (안 되면 예전 방식으로 자동 전환)
  bool _rawInputOk = true;

  // 장구류별 맞춤 합격 기준치
  static const Map<String, double> classThresholds = {
    'helmet': 0.40,
    'helmet_nostrap': 0.35,
    'safety_shoes': 0.40,
    'welding_shield': 0.35,
    'face_shield': 0.30,
    'protective_suit': 0.30,
    'safety_harness': 0.28,
    'gaiters': 0.20,
    'welding_gaiters': 0.20,
    'safety_glasses': 0.35,
    'dust_mask': 0.20,
    'gas_mask': 0.20,
    'safety_gloves': 0.20,
    'chemical_gloves': 0.20,
    'welding_gloves': 0.20,
    'safety_hook': 0.18,
  };

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = numThreads;
      _interpreter = await Interpreter.fromAsset(
        'assets/best.tflite',
        options: options,
      );
      print('✅ [TFLite] 모델 로드 완료! (스레드 $numThreads개)');
    } catch (e) {
      print('❌ [TFLite] 모델 로드 실패: $e');
    }
  }

  Future<List<Detection>> detect(img.Image image) async {
    if (_interpreter == null) return [];

    final int origW = image.width;
    final int origH = image.height;

    // 1. 비율 유지 리사이즈 (Letterbox)
    final double scale = min(inputSize / origW, inputSize / origH);
    final int newWidth = (origW * scale).round();
    final int newHeight = (origH * scale).round();
    final resized = img.copyResize(image, width: newWidth, height: newHeight);

    final int padX = (inputSize - newWidth) ~/ 2;
    final int padY = (inputSize - newHeight) ~/ 2;

    // 2. 입력 텐서 구성 (픽셀 하나씩 getPixel → 한 줄씩 바이트 복사로 변경)
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final bool isNCHW = (inputShape.length == 4 && inputShape[1] == 3);
    const double padValue = 114.0 / 255.0;
    const int plane = inputSize * inputSize;

    // 리사이즈된 이미지의 RGB 바이트 (r,g,b,r,g,b,...)
    final Uint8List rgb = resized.getBytes(order: img.ChannelOrder.rgb);

    // 전체를 패딩 색으로 채운 뒤, 이미지 영역만 덮어씀
    final input = Float32List(3 * plane)..fillRange(0, 3 * plane, padValue);
    final norm = _norm;

    if (isNCHW) {
      // [1,3,640,640]
      for (int y = 0; y < newHeight; y++) {
        int src = y * newWidth * 3;
        int dst = (y + padY) * inputSize + padX;
        for (int x = 0; x < newWidth; x++) {
          input[dst] = norm[rgb[src]];
          input[plane + dst] = norm[rgb[src + 1]];
          input[2 * plane + dst] = norm[rgb[src + 2]];
          src += 3;
          dst++;
        }
      }
    } else {
      // [1,640,640,3]
      for (int y = 0; y < newHeight; y++) {
        int src = y * newWidth * 3;
        int dst = ((y + padY) * inputSize + padX) * 3;
        final int rowEnd = src + newWidth * 3;
        while (src < rowEnd) {
          input[dst++] = norm[rgb[src++]];
        }
      }
    }

    // 3. 출력 버퍼 및 모델 실행
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int totalOutputElements = outputShape.reduce((a, b) => a * b);
    final output = List.filled(totalOutputElements, 0.0).reshape(outputShape);

    // 입력은 바이트 그대로 넘김 (중첩 리스트 변환 생략 → 빠름)
    // 혹시 이 방식이 안 되는 버전이면 예전 방식(reshape)으로 자동 전환
    if (_rawInputOk) {
      try {
        _interpreter!.run(input.buffer.asUint8List(), output);
      } catch (e) {
        print('⚠️ [TFLite] 바이트 입력 실패 → 예전 방식으로 전환: $e');
        _rawInputOk = false;
        _interpreter!.run(input.reshape(inputShape), output);
      }
    } else {
      _interpreter!.run(input.reshape(inputShape), output);
    }

    // 4. 후보 박스 추출 (좌표 + 클래스 + 점수)
    // 출력 [1,20,8400] (channel-first) 또는 [1,8400,20]
    final bool isChannelFirst =
        (outputShape[1] == 20 && outputShape[2] == 8400);

    final List<_Candidate> candidates = [];

    for (int i = 0; i < 8400; i++) {
      // 박스 좌표 (모델 입력 640 기준, cx cy w h)
      final double cx = isChannelFirst
          ? (output[0][0][i] as double)
          : (output[0][i][0] as double);
      final double cy = isChannelFirst
          ? (output[0][1][i] as double)
          : (output[0][i][1] as double);
      final double w = isChannelFirst
          ? (output[0][2][i] as double)
          : (output[0][i][2] as double);
      final double h = isChannelFirst
          ? (output[0][3][i] as double)
          : (output[0][i][3] as double);

      // 클래스별 점수 중 최고
      double bestScore = 0;
      int bestClass = -1;
      for (int c = 0; c < numClasses; c++) {
        final double score = isChannelFirst
            ? (output[0][4 + c][i] as double)
            : (output[0][i][4 + c] as double);
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestClass < 0) continue;
      final label = ppeLabels[bestClass];
      final threshold = classThresholds[label] ?? defaultThreshold;
      if (bestScore < threshold) continue;

      // 좌표가 정규화(0~1)일 수도, 픽셀(0~640)일 수도 → 자동 판별
      double cxP = cx, cyP = cy, wP = w, hP = h;
      if (cx <= 1.0 && cy <= 1.0 && w <= 1.0 && h <= 1.0) {
        cxP = cx * inputSize;
        cyP = cy * inputSize;
        wP = w * inputSize;
        hP = h * inputSize;
      }

      candidates.add(_Candidate(label, bestScore, cxP, cyP, wP, hP));
    }

    // 5. NMS (겹치는 박스 제거)
    final List<_Candidate> kept = _suppressConfusable(
      _nms(candidates, iouThreshold),
    );

    // 6. 좌표를 원본 이미지 픽셀로 역변환 (레터박싱 되돌리기)
    final List<Detection> results = [];
    for (final c in kept) {
      // 640 기준 (cx,cy,w,h) → 좌상단 (x,y,w,h)
      double x = c.cx - c.w / 2;
      double y = c.cy - c.h / 2;
      // 패딩 제거 → 리사이즈 비율 되돌림
      x = (x - padX) / scale;
      y = (y - padY) / scale;
      final double bw = c.w / scale;
      final double bh = c.h / scale;

      // 원본 범위로 클램프
      final double left = x.clamp(0.0, origW.toDouble());
      final double top = y.clamp(0.0, origH.toDouble());
      final double width = bw.clamp(0.0, origW - left);
      final double height = bh.clamp(0.0, origH - top);

      results.add(Detection(c.label, c.score, left, top, width, height));
    }

    // 7. 디버그: 감지된 것 출력 (printDetections = true일 때만)
    if (printDetections) {
      print('================ [TFLite 감지 결과] ================');
      for (final d in results) {
        print(
          ' ${d.label.padRight(16)} : ${(d.confidence * 100).toStringAsFixed(1)}%  '
          'box(${d.left.toStringAsFixed(0)},${d.top.toStringAsFixed(0)},'
          '${d.width.toStringAsFixed(0)},${d.height.toStringAsFixed(0)})',
        );
      }
      print('총 ${results.length}개 감지');
      print('===================================================');
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  // NMS: 점수 높은 순으로, 많이 겹치는(IoU>기준) 박스 제거
  List<_Candidate> _nms(List<_Candidate> cands, double iouThresh) {
    cands.sort((a, b) => b.score.compareTo(a.score));
    final List<_Candidate> kept = [];
    final List<bool> removed = List.filled(cands.length, false);

    for (int i = 0; i < cands.length; i++) {
      if (removed[i]) continue;
      kept.add(cands[i]);
      for (int j = i + 1; j < cands.length; j++) {
        if (removed[j]) continue;
        // 같은 클래스끼리만 겹침 제거 (다른 장비는 겹쳐도 됨)
        if (cands[i].label != cands[j].label) continue;
        if (_iou(cands[i], cands[j]) > iouThresh) {
          removed[j] = true;
        }
      }
    }
    return kept;
  }

  // 헷갈리는 장비끼리 겹치면 신뢰도 높은 것만 남김 (점수 높은 순으로 들어옴)
  // 겹침 = 교집합 / 작은 박스 넓이 (한 박스가 다른 박스 안에 들어가도 잡힘)
  List<_Candidate> _suppressConfusable(List<_Candidate> cands) {
    final List<_Candidate> sorted = List.of(cands)
      ..sort((a, b) => b.score.compareTo(a.score));
    final List<_Candidate> kept = [];
    for (final c in sorted) {
      bool drop = false;
      for (final k in kept) {
        if (k.label == c.label) continue; // 같은 장비는 NMS에서 처리됨
        final bool sameGroup = confusableGroups.any(
          (g) => g.contains(k.label) && g.contains(c.label),
        );
        if (sameGroup && _overlapSmall(k, c) > confusableOverlap) {
          drop = true; // k가 점수 더 높음 → c 버림
          break;
        }
      }
      if (!drop) kept.add(c);
    }
    return kept;
  }

  // 교집합 / 작은 박스 넓이
  double _overlapSmall(_Candidate a, _Candidate b) {
    final double ix1 = max(a.cx - a.w / 2, b.cx - b.w / 2);
    final double iy1 = max(a.cy - a.h / 2, b.cy - b.h / 2);
    final double ix2 = min(a.cx + a.w / 2, b.cx + b.w / 2);
    final double iy2 = min(a.cy + a.h / 2, b.cy + b.h / 2);
    final double inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1);
    final double smaller = min(a.w * a.h, b.w * b.h);
    if (smaller <= 0) return 0;
    return inter / smaller;
  }

  // IoU (두 박스 겹침 비율)
  double _iou(_Candidate a, _Candidate b) {
    final double ax1 = a.cx - a.w / 2, ay1 = a.cy - a.h / 2;
    final double ax2 = a.cx + a.w / 2, ay2 = a.cy + a.h / 2;
    final double bx1 = b.cx - b.w / 2, by1 = b.cy - b.h / 2;
    final double bx2 = b.cx + b.w / 2, by2 = b.cy + b.h / 2;

    final double ix1 = max(ax1, bx1), iy1 = max(ay1, by1);
    final double ix2 = min(ax2, bx2), iy2 = min(ay2, by2);
    final double iw = max(0.0, ix2 - ix1), ih = max(0.0, iy2 - iy1);
    final double inter = iw * ih;
    final double areaA = a.w * a.h, areaB = b.w * b.h;
    final double union = areaA + areaB - inter;
    if (union <= 0) return 0;
    return inter / union;
  }

  void dispose() {
    _interpreter?.close();
  }
}

// 내부용 후보 박스 (640 기준 cx,cy,w,h)
class _Candidate {
  final String label;
  final double score;
  final double cx;
  final double cy;
  final double w;
  final double h;
  _Candidate(this.label, this.score, this.cx, this.cy, this.w, this.h);
}
