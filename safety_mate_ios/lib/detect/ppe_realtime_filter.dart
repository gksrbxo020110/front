import 'dart:math';
import 'ppe_detector.dart';

// ─────────────────────────────────────────────
// 실시간 감지 공통 "인정 규칙" (게이트 · Inspection 공통)
//   - 신뢰도 60% 이상 = 초록 (착용 인정 후보)
//   - 40~59% = 노랑 (애매함 → 재인식 유도)
//   - 40% 미만 = 무시
// ─────────────────────────────────────────────
class PpeRealtimeFilter {
  static const double minConfidence = 0.6;
  static const double weakConfidence = 0.4;
  static const int minHits = 2;
  static const double dupMaxIou = 0.3;

  // 양쪽에 하나씩 있어야 하는 장비 (팀 결정: 장갑 3종 + 안전화 + 각반 2종)
  static const Set<String> pairLabels = {
    'safety_gloves',
    'chemical_gloves',
    'welding_gloves',
    'safety_shoes',
    'gaiters',
    'welding_gaiters',
  };

  static const Map<String, String> pairMissingText = {
    'safety_gloves': '⚠ 장갑을 양손에 모두 착용하세요',
    'chemical_gloves': '⚠ 내화학장갑을 양손에 모두 착용하세요',
    'welding_gloves': '⚠ 용접장갑을 양손에 모두 착용하세요',
    'safety_shoes': '⚠ 안전화를 양발에 모두 착용하세요 · 두 발이 보이게 해주세요',
    'gaiters': '⚠ 각반을 양다리에 모두 착용하세요 · 두 다리가 보이게 해주세요',
    'welding_gaiters': '⚠ 용접각반을 양다리에 모두 착용하세요 · 두 다리가 보이게 해주세요',
  };

  static const Set<String> singleLabels = {
    'helmet',
    'helmet_nostrap',
    'safety_harness',
    'protective_suit',
    'dust_mask',
    'gas_mask',
    'face_shield',
    'welding_shield',
    'safety_glasses',
  };

  final Map<String, int> _hits = {};
  final Map<String, int> _pairHits = {};
  final Map<String, Detection> _best = {};
  final Map<String, int> _weakHits = {};
  final Map<String, int> _pairWeakHits = {};

  // 최근성 추적: 한 번 확정돼도 최근에 초록이 안 보이면 확정 해제
  int _frame = 0;
  final Map<String, int> _lastStrongFrame = {};
  static const int recentWindow = 3; // 최근 N프레임 안에 초록이 있어야 확정 유지

  void reset() {
    _hits.clear();
    _pairHits.clear();
    _best.clear();
    _weakHits.clear();
    _pairWeakHits.clear();
    _frame = 0;
    _lastStrongFrame.clear();
  }

  static bool isStrong(Detection d) => d.confidence >= minConfidence;
  static bool isWeak(Detection d) =>
      d.confidence >= weakConfidence && d.confidence < minConfidence;
  static bool isVisible(Detection d) => d.confidence >= weakConfidence;

  List<Detection> addFrame(List<Detection> detections) {
    _frame++;
    final strong = detections.where(isStrong).toList();

    final labelsThisFrame = strong.map((d) => d.label).toSet();
    for (final label in labelsThisFrame) {
      _hits[label] = (_hits[label] ?? 0) + 1;
      _lastStrongFrame[label] = _frame; // 이번 프레임에 초록으로 보임

      if (pairLabels.contains(label)) {
        final same = strong.where((d) => d.label == label).toList();
        if (distinctCount(same) >= 2) {
          _pairHits[label] = (_pairHits[label] ?? 0) + 1;
        }
      }
    }

    final weakLabels = detections.where(isWeak).map((d) => d.label).toSet();
    for (final label in weakLabels) {
      _weakHits[label] = (_weakHits[label] ?? 0) + 1;
    }

    for (final label in pairLabels) {
      final strongSame = strong.where((d) => d.label == label).toList();
      if (strongSame.isEmpty || distinctCount(strongSame) >= 2) continue;
      final visibleSame = detections
          .where((d) => d.label == label && isVisible(d))
          .toList();
      if (distinctCount(visibleSame) >= 2) {
        _pairWeakHits[label] = (_pairWeakHits[label] ?? 0) + 1;
      }
    }

    for (final d in strong) {
      final prev = _best[d.label];
      if (prev == null || d.confidence > prev.confidence) {
        _best[d.label] = d;
      }
    }
    return strong;
  }

  Set<String> get confirmedLabels => _hits.entries
      .where((e) => e.value >= minHits)
      .where((e) => !pairLabels.contains(e.key) || (_pairHits[e.key] ?? 0) >= 1)
      // 최근 N프레임 안에 초록이 안 보였으면 확정 해제 (노랑으로 떨어진 것 반영)
      .where((e) => _frame - (_lastStrongFrame[e.key] ?? -1000) <= recentWindow)
      .map((e) => e.key)
      .toSet();

  List<Detection> get confirmedDetections {
    final ok = confirmedLabels;
    return _best.values.where((d) => ok.contains(d.label)).toList();
  }

  bool get hasAnyStrong => _hits.isNotEmpty;
  bool get hasAnyVisible => _hits.isNotEmpty || _weakHits.isNotEmpty;

  bool isUncertain(String label) {
    if (confirmedLabels.contains(label)) return false;
    if (pairLabels.contains(label) &&
        hitsOf(label) >= minHits &&
        (_pairHits[label] ?? 0) == 0) {
      return (_pairWeakHits[label] ?? 0) > 0;
    }
    return (_weakHits[label] ?? 0) > 0;
  }

  int hitsOf(String label) => _hits[label] ?? 0;

  bool pairMissing(String label) =>
      hitsOf(label) >= minHits && (_pairHits[label] ?? 0) == 0;

  bool get anyPairMissing => pairLabels.any(pairMissing);

  String? get pairMissingMessage {
    for (final label in pairLabels) {
      if (pairMissing(label)) return pairMissingText[label];
    }
    return null;
  }

  static String? duplicateLabel(List<Detection> strong) {
    for (final label in singleLabels) {
      final same = strong.where((d) => d.label == label).toList();
      if (distinctCount(same) >= 2) return label;
    }
    return null;
  }

  static int distinctCount(List<Detection> ds) {
    final sorted = [...ds]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    for (final d in sorted) {
      if (kept.every((k) => _iou(k, d) < dupMaxIou)) kept.add(d);
    }
    return kept.length;
  }

  static double _iou(Detection a, Detection b) {
    final double x1 = max(a.left, b.left);
    final double y1 = max(a.top, b.top);
    final double x2 = min(a.left + a.width, b.left + b.width);
    final double y2 = min(a.top + a.height, b.top + b.height);
    final double inter = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final double union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0 : inter / union;
  }
}
