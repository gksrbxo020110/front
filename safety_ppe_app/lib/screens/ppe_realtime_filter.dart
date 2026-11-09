import 'dart:math';
import 'ppe_detector.dart';

// ─────────────────────────────────────────────
// 실시간 감지 공통 "인정 규칙" (게이트 · Inspection 공통)
//
// 팀 기준 (iOS와 동일):
//   - 신뢰도 60% 이상 = 초록 (착용 인정 후보)
//   - 40~59% = 노랑 (애매함 → 재인식 유도, 착용 인정 안 함)
//   - 40% 미만 = 무시 (화면에도 안 보임)
// 착용 인정: 초록이 서로 다른 프레임에서 minHits번 이상
// 짝 장비(장갑·안전화·각반): 감지 중 한 번이라도 2개가 같이 보여야 인정 (한쪽만이면 미착용)
// 중복: 1개짜리 장비(안전모 등)가 2개 → 여러 명 의심, 그 프레임은 판정에서 제외
// ─────────────────────────────────────────────
class PpeRealtimeFilter {
  // ★ 조정할 숫자
  static const double minConfidence = 0.6; // 초록 (착용 인정 후보)
  static const double weakConfidence = 0.4; // 노랑 시작 (40~59%)
  static const int minHits = 2; // 몇 프레임에서 초록으로 잡혀야 인정할지
  static const double dupMaxIou = 0.3; // 이 이상 겹치면 같은 물건으로 봄 (개수 셀 때)

  // 양쪽에 하나씩 있어야 하는 장비 (2개가 같이 보여야 인정)
  // 팀 결정(11/9): 장갑 3종 + 안전화 + 각반 2종
  static const Set<String> pairLabels = {
    'safety_gloves', // 양손
    'chemical_gloves', // 양손
    'welding_gloves', // 양손
    'safety_shoes', // 양발
    'gaiters', // 양다리
    'welding_gaiters', // 양다리
  };

  // 짝 장비 한쪽만일 때 안내 문구
  static const Map<String, String> pairMissingText = {
    'safety_gloves': '⚠ 장갑을 양손에 모두 착용하세요',
    'chemical_gloves': '⚠ 내화학장갑을 양손에 모두 착용하세요',
    'welding_gloves': '⚠ 용접장갑을 양손에 모두 착용하세요',
    'safety_shoes': '⚠ 안전화를 양발에 모두 착용하세요 · 두 발이 보이게 해주세요',
    'gaiters': '⚠ 각반을 양다리에 모두 착용하세요 · 두 다리가 보이게 해주세요',
    'welding_gaiters': '⚠ 용접각반을 양다리에 모두 착용하세요 · 두 다리가 보이게 해주세요',
  };

  // 한 사람에게 1개뿐인 장비 → 2개 이상이면 여러 명 의심
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

  // 라벨별 초록 감지가 나온 프레임 수
  final Map<String, int> _hits = {};

  // 짝 장비(장갑)가 한 프레임에 2개 이상 같이 잡힌 프레임 수
  final Map<String, int> _pairHits = {};

  // 라벨별 최고 신뢰도 감지 (저장할 때 items로 보냄)
  final Map<String, Detection> _best = {};

  // 라벨별 노랑(40~59%) 감지가 나온 프레임 수 → 시간 종료 시 "애매" 판단
  final Map<String, int> _weakHits = {};

  // 짝 장비: 한 프레임에 초록 1개 이상 + 다른 위치에 노랑까지 합쳐 2개 이상 보인 프레임 수
  // (한쪽은 초록, 다른 쪽은 흐리게 보임 → 한쪽만 착용이 아니라 "애매")
  final Map<String, int> _pairWeakHits = {};

  // 새 사람 감지 시작할 때 초기화
  void reset() {
    _hits.clear();
    _pairHits.clear();
    _best.clear();
    _weakHits.clear();
    _pairWeakHits.clear();
  }

  // 초록 (60% 이상)
  static bool isStrong(Detection d) => d.confidence >= minConfidence;

  // 노랑 (40~59%)
  static bool isWeak(Detection d) =>
      d.confidence >= weakConfidence && d.confidence < minConfidence;

  // 화면·저장 사진에 그릴 것 (초록 + 노랑)
  static bool isVisible(Detection d) => d.confidence >= weakConfidence;

  // 한 프레임의 감지 결과를 넣음 → 이번 프레임의 초록 감지만 돌려줌
  List<Detection> addFrame(List<Detection> detections) {
    final strong = detections.where(isStrong).toList();

    // 같은 프레임에서 같은 라벨이 여러 개여도 1번으로 셈
    final labelsThisFrame = strong.map((d) => d.label).toSet();
    for (final label in labelsThisFrame) {
      _hits[label] = (_hits[label] ?? 0) + 1;

      // 짝 장비: 이번 프레임에 2개(서로 다른 위치)가 같이 잡혔는지
      if (pairLabels.contains(label)) {
        final same = strong.where((d) => d.label == label).toList();
        if (distinctCount(same) >= 2) {
          _pairHits[label] = (_pairHits[label] ?? 0) + 1;
        }
      }
    }

    // 노랑 기록
    final weakLabels = detections.where(isWeak).map((d) => d.label).toSet();
    for (final label in weakLabels) {
      _weakHits[label] = (_weakHits[label] ?? 0) + 1;
    }

    // 짝 장비: 초록이 있는데 짝이 아직 안 맞은 프레임에서, 노랑까지 합치면 2개인지
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

  // 인정된 라벨 → PpeRules.evaluate에 넣을 값
  //  - minHits번 이상 초록
  //  - 짝 장비(장갑·안전화·각반)는 2개가 같이 보인 적이 한 번 이상
  Set<String> get confirmedLabels => _hits.entries
      .where((e) => e.value >= minHits)
      .where((e) => !pairLabels.contains(e.key) || (_pairHits[e.key] ?? 0) >= 1)
      .map((e) => e.key)
      .toSet();

  // 인정된 라벨의 최고 신뢰도 감지들 → 저장할 때 items로 사용
  List<Detection> get confirmedDetections {
    final ok = confirmedLabels;
    return _best.values.where((d) => ok.contains(d.label)).toList();
  }

  // 초록 감지가 한 번이라도 있었는지 (없으면 "인식률 낮음" → 빈 사진 저장 방지)
  bool get hasAnyStrong => _hits.isNotEmpty;

  // 초록이든 노랑이든 무언가 보인 적이 있는지
  bool get hasAnyVisible => _hits.isNotEmpty || _weakHits.isNotEmpty;

  // ── 시간 종료 시 "애매"인지 (팀 결정 11/9) ──
  //  - 인정된 장비 → 애매 아님 (착용)
  //  - 짝 장비가 한쪽만 초록: 다른 쪽이 노랑으로라도 같이 보였으면 애매, 아니면 미착용(한쪽만 착용)
  //  - 그 외: 노랑으로 잡힌 적이 있으면 애매, 없으면 미착용
  bool isUncertain(String label) {
    if (confirmedLabels.contains(label)) return false;
    if (pairLabels.contains(label) &&
        hitsOf(label) >= minHits &&
        (_pairHits[label] ?? 0) == 0) {
      return (_pairWeakHits[label] ?? 0) > 0;
    }
    return (_weakHits[label] ?? 0) > 0;
  }

  // 특정 라벨이 몇 프레임에서 초록으로 잡혔는지
  int hitsOf(String label) => _hits[label] ?? 0;

  // 짝 장비가 한쪽만 계속 보이는지 (안내 문구용)
  bool pairMissing(String label) =>
      hitsOf(label) >= minHits && (_pairHits[label] ?? 0) == 0;

  // 짝 장비 중 하나라도 한쪽만인지
  bool get anyPairMissing => pairLabels.any(pairMissing);

  // 한쪽만 보이는 짝 장비의 안내 문구 (없으면 null)
  String? get pairMissingMessage {
    for (final label in pairLabels) {
      if (pairMissing(label)) return pairMissingText[label];
    }
    return null;
  }

  // ── 중복 감지: 1개짜리 장비가 이번 프레임에 2개 이상이면 그 라벨 반환 ──
  static String? duplicateLabel(List<Detection> strong) {
    for (final label in singleLabels) {
      final same = strong.where((d) => d.label == label).toList();
      if (distinctCount(same) >= 2) return label;
    }
    return null;
  }

  // 서로 다른 위치의 개수 (많이 겹치는 박스는 같은 물건으로 봄)
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
