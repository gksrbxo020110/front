import 'ppe_rules.dart';
import 'ppe_realtime_filter.dart';

// ─────────────────────────────────────────────
// 시간 종료(또는 점검 완료) 판정 — 게이트 · Inspection 공통 (팀 결정 11/9)
//
//  - 착용   : 초록으로 인정됨 (짝 장비는 양쪽)
//  - 미착용 : 한 번도 안 보임 / 짝 장비 한쪽만 → 바로 기록
//  - 애매   : 노란 박스로만 잡힘 (짝 장비는 한쪽 초록 + 다른 쪽 노랑 포함)
//             → 1번째: 기록 안 하고 재촬영 / 2번째: 관리자 결정
// ─────────────────────────────────────────────
class JudgeOutcome {
  final bool allWorn;
  final List<String> ambiguousNames; // 애매한 항목 이름 (화면 표시용)
  final List<String> ambiguousLabels; // 애매한 항목 대표 라벨 (저장할 때 빼거나 넣음)
  final List<String> missingLabels; // 확실한 미착용 대표 라벨 (애매 제외)
  final List<String> missingNames; // 확실한 미착용 이름 (화면 표시용)

  const JudgeOutcome({
    required this.allWorn,
    required this.ambiguousNames,
    required this.ambiguousLabels,
    required this.missingLabels,
    required this.missingNames,
  });

  bool get hasAmbiguous => ambiguousNames.isNotEmpty;
  bool get hasMissing => missingLabels.isNotEmpty;

  // 관리자가 "미착용으로 기록" → 확실한 미착용 + 애매 전부
  List<String> get allMissingLabels => [...missingLabels, ...ambiguousLabels];
}

JudgeOutcome judgeAtEnd({
  required String workType,
  required InspectionResult result,
  required Set<String> judgedLabels,
  required PpeRealtimeFilter filter,
}) {
  // 체크리스트 이름 → 라벨 (택1 그룹은 첫 번째가 대표 라벨 = PpeRules.missingLabels와 같음)
  final Map<String, List<String>> labelsOf = {};
  for (final r in PpeRules.requirementsFor(workType)) {
    labelsOf.putIfAbsent(r.displayName, () => r.labels);
  }
  // 용접 특수 규칙 항목 (evaluate에서 따로 추가되는 것)
  labelsOf.putIfAbsent('보안면', () => const ['welding_shield']);
  labelsOf.putIfAbsent('방진마스크', () => const ['dust_mask']);
  labelsOf.putIfAbsent(
    '보안경/안면보호대',
    () => const ['face_shield', 'safety_glasses'],
  );

  // 용접: 보안면이 흐리게(노랑) 보였으면, 보안면 대신 확인하는 마스크·눈 보호구도 애매
  final bool weldingShieldUncertain =
      workType.contains('용접') && filter.isUncertain('welding_shield');

  final List<String> ambNames = [];
  final List<String> ambLabels = [];
  for (final c in result.checklist) {
    if (c.worn) continue;
    final labels = labelsOf[c.displayName] ?? const <String>[];
    if (labels.isEmpty) continue;
    final bool faceItem =
        c.displayName == '방진마스크' || c.displayName == '보안경/안면보호대';
    if (labels.any(filter.isUncertain) ||
        (faceItem && weldingShieldUncertain)) {
      ambNames.add(c.displayName);
      ambLabels.add(labels.first);
    }
  }

  // 확실한 미착용 = 전체 미착용 - 애매
  final allMissing = PpeRules.missingLabels(workType, judgedLabels);
  final missing = allMissing.where((l) => !ambLabels.contains(l)).toList();

  final List<String> missNames = [];
  for (final c in result.checklist) {
    if (!c.worn && !ambNames.contains(c.displayName)) {
      missNames.add(c.displayName);
    }
  }

  return JudgeOutcome(
    allWorn: result.allWorn,
    ambiguousNames: ambNames,
    ambiguousLabels: ambLabels,
    missingLabels: missing,
    missingNames: missNames,
  );
}
