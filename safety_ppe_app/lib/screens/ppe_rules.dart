// 작업종류별 PPE 요구사항 + 착용/미착용 판정 로직
// 모델 라벨(ppe_labels.dart) 기준

// 판정에 쓸 항목 하나 (필수 or 택1 그룹)
class PpeRequirement {
  final String displayName; // 화면 표시 이름 (예: "보안경/안면보호대")
  final List<String> labels; // 이 중 하나라도 감지되면 OK (택1). 1개면 필수.
  const PpeRequirement(this.displayName, this.labels);
}

// 판정 결과 항목 (체크리스트용)
class PpeCheckResult {
  final String displayName;
  final bool worn; // 착용(감지)됐는지
  const PpeCheckResult(this.displayName, this.worn);
}

// 전체 판정 결과
class InspectionResult {
  final bool allWorn; // 전부 착용? (작업 가능 여부)
  final List<PpeCheckResult> checklist; // 항목별 결과
  const InspectionResult(this.allWorn, this.checklist);
}

class PpeRules {
  // 작업종류 이름 → 요구사항 목록
  // 화면에서 넘어오는 workType 이름과 맞춰야 함
  // (InspectionWorkScreen의 works: 일반작업/고소작업/분진작업/화학작업/용접작업)
  static List<PpeRequirement> requirementsFor(String workType) {
    // 공통 4종
    const common = [
      PpeRequirement('안전모', ['helmet']),
      PpeRequirement('안전화', ['safety_shoes']),
      PpeRequirement('안전장갑', ['safety_gloves']),
      PpeRequirement('각반', ['gaiters']),
    ];

    if (workType.contains('고소')) {
      return [
        ...common,
        const PpeRequirement('안전대', ['safety_harness']),
        const PpeRequirement('안전고리', ['safety_hook']),
      ];
    }

    if (workType.contains('분진')) {
      return [
        ...common,
        const PpeRequirement('방진마스크', ['dust_mask']),
        // 안면보호대 또는 보안경 (택1)
        const PpeRequirement('보안경/안면보호대', ['face_shield', 'safety_glasses']),
      ];
    }

    if (workType.contains('화학')) {
      return [
        const PpeRequirement('안전모', ['helmet']),
        const PpeRequirement('안전화', ['safety_shoes']),
        const PpeRequirement('내화학장갑', ['chemical_gloves']),
        const PpeRequirement('각반', ['gaiters']),
        const PpeRequirement('보호복', ['protective_suit']),
        const PpeRequirement('방독마스크', ['gas_mask']),
        const PpeRequirement('보안경/안면보호대', ['face_shield', 'safety_glasses']),
      ];
    }

    if (workType.contains('용접')) {
      // 용접은 보안면 유무에 따라 규칙이 바뀌므로 별도 함수에서 처리
      // 여기선 기본 필수만 반환 (실제 판정은 evaluate에서 특수처리)
      return [
        const PpeRequirement('안전모', ['helmet']),
        const PpeRequirement('안전화', ['safety_shoes']),
        const PpeRequirement('용접장갑', ['welding_gloves']),
        const PpeRequirement('용접각반', ['welding_gaiters']),
        // 보안면 규칙은 evaluate에서
      ];
    }

    // 일반작업(기본) = 공통 4종
    return common;
  }

  // 감지된 라벨 집합으로 착용/미착용 판정
  static InspectionResult evaluate(
    String workType,
    Set<String> detectedLabels,
  ) {
    final List<PpeCheckResult> checklist = [];

    // 기본 요구사항 판정
    final reqs = requirementsFor(workType);
    for (final r in reqs) {
      // 택1 그룹: labels 중 하나라도 감지되면 착용
      final worn = r.labels.any((l) => detectedLabels.contains(l));
      checklist.add(PpeCheckResult(r.displayName, worn));
    }

    // 용접 특수 규칙 추가
    if (workType.contains('용접')) {
      final hasShield = detectedLabels.contains('welding_shield');
      if (hasShield) {
        // 보안면 있으면 그것만으로 OK
        checklist.add(const PpeCheckResult('보안면', true));
      } else {
        // 보안면 없으면 방진마스크 + (안면보호대 or 보안경) 필요
        final hasMask = detectedLabels.contains('dust_mask');
        checklist.add(PpeCheckResult('방진마스크', hasMask));
        final hasEye =
            detectedLabels.contains('face_shield') ||
            detectedLabels.contains('safety_glasses');
        checklist.add(PpeCheckResult('보안경/안면보호대', hasEye));
      }
    }

    // 전부 착용됐는지
    final allWorn = checklist.every((c) => c.worn);
    return InspectionResult(allWorn, checklist);
  }

  // ── 착용 안 된 필수 항목 → 대표 라벨 목록 ──
  // 서버는 items 중 worn=false가 있어야 "미착용"으로 판단함 (등급·알림·푸시)
  // → 저장할 때 이 목록을 worn=false로 같이 보내야 함
  // 택1 그룹이 빠졌으면 그룹의 첫 번째 라벨 하나만 반환
  static List<String> missingLabels(
    String workType,
    Set<String> detectedLabels,
  ) {
    final List<String> missing = [];

    for (final r in requirementsFor(workType)) {
      final worn = r.labels.any((l) => detectedLabels.contains(l));
      if (!worn) missing.add(r.labels.first);
    }

    // 용접: 보안면이 없을 때만 방진마스크·눈 보호구 확인
    if (workType.contains('용접') && !detectedLabels.contains('welding_shield')) {
      if (!detectedLabels.contains('dust_mask')) {
        missing.add('dust_mask');
      }
      if (!detectedLabels.contains('face_shield') &&
          !detectedLabels.contains('safety_glasses')) {
        missing.add('face_shield');
      }
    }

    return missing;
  }
}
