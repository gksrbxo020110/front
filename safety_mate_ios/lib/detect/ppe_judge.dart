import 'ppe_rules.dart';
import 'ppe_realtime_filter.dart';

// ─────────────────────────────────────────────
// 시간 종료(또는 점검 완료) 판정 — 게이트 · Inspection 공통 (팀 결정 11/9)
//  - 착용   : 초록으로 인정됨 (짝 장비는 양쪽)
//  - 미착용 : 한 번도 안 보임 / 짝 장비 한쪽만 → 바로 기록
//  - 애매   : 노란 박스로만 잡힘 → 1번째 재촬영 / 2번째 관리자 결정
// ─────────────────────────────────────────────
class JudgeOutcome {
  final bool allWorn;
  final List<String> ambiguousNames;
  final List<String> ambiguousLabels;
  final List<String> missingLabels;
  final List<String> missingNames;

  const JudgeOutcome({
    required this.allWorn,
    required this.ambiguousNames,
    required this.ambiguousLabels,
    required this.missingLabels,
    required this.missingNames,
  });

  bool get hasAmbiguous => ambiguousNames.isNotEmpty;
  bool get hasMissing => missingLabels.isNotEmpty;

  List<String> get allMissingLabels => [...missingLabels, ...ambiguousLabels];
}

JudgeOutcome judgeAtEnd({
  required String workType,
  required InspectionResult result,
  required Set<String> judgedLabels,
  required PpeRealtimeFilter filter,
}) {
  final Map<String, List<String>> labelsOf = {};
  for (final r in PpeRules.requirementsFor(workType)) {
    labelsOf.putIfAbsent(r.displayName, () => r.labels);
  }
  labelsOf.putIfAbsent('보안면', () => const ['welding_shield']);
  labelsOf.putIfAbsent('방진마스크', () => const ['dust_mask']);
  labelsOf.putIfAbsent(
    '보안경/안면보호대',
    () => const ['face_shield', 'safety_glasses'],
  );

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
