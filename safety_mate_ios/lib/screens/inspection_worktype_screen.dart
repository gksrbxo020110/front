import 'package:flutter/material.dart';
import '../theme.dart';
import 'inspection_worker_screen.dart';

// 작업종류별 필수 PPE 정의 (그룹 방식)
// requiredGroups: 그룹의 리스트. 각 그룹은 [A, B]면 "A 또는 B 하나라도 감지되면 충족"(OR)
//   단독 [A]면 그냥 필수. 모든 그룹이 충족돼야 통과.
// isWelding: 용접작업은 보안면 유무에 따라 판정이 달라져 특수 처리
class WorkTypeGear {
  final String name; // 작업종류 이름 (서버 전송 workType으로도 사용)
  final IconData icon;
  final List<List<String>> requiredGroups; // 필수 PPE 그룹들 (그룹 내부는 OR)
  final bool isWelding;

  const WorkTypeGear({
    required this.name,
    required this.icon,
    required this.requiredGroups,
    this.isWelding = false,
  });

  // 표시용 텍스트 (그룹별로, OR이면 "A/B")
  String get displayItems {
    return requiredGroups
        .map((group) => group.map((g) => gearKoreanNames[g] ?? g).join('/'))
        .join('·');
  }

  // 이 작업에서 감지 대상이 되는 모든 PPE 클래스 (화면 표시·전송용, 중복 제거)
  List<String> get allGear {
    final set = <String>{};
    for (final group in requiredGroups) {
      set.addAll(group);
    }
    if (isWelding) {
      // 용접은 보안면·방진마스크·눈보호가 조건부라 다 포함시켜 표시
      set.addAll([
        'welding_shield',
        'dust_mask',
        'safety_glasses',
        'face_shield',
      ]);
    }
    return set.toList();
  }
}

// 모델 클래스 → 한글 이름 (표시용)
const Map<String, String> gearKoreanNames = {
  'helmet': '안전모',
  'safety_shoes': '안전화',
  'safety_gloves': '안전장갑',
  'gaiters': '각반',
  'safety_harness': '안전대',
  'safety_hook': '안전고리',
  'dust_mask': '방진마스크',
  'gas_mask': '방독마스크',
  'safety_glasses': '보안경',
  'face_shield': '안면보호대',
  'protective_suit': '보호복',
  'chemical_gloves': '내화학장갑',
  'welding_shield': '보안면',
  'welding_gloves': '용접장갑',
  'welding_gaiters': '용접각반',
};

// 작업종류 5개 정의 (조장 확정 목록 기준)
const List<WorkTypeGear> kWorkTypes = [
  // 고소작업: 공통4 + 안전대 + 안전고리 (다 단독 필수)
  WorkTypeGear(
    name: '고소작업',
    icon: Icons.stairs,
    requiredGroups: [
      ['helmet'],
      ['safety_shoes'],
      ['safety_gloves'],
      ['gaiters'],
      ['safety_harness'],
      ['safety_hook'],
    ],
  ),
  // 분진작업: 공통4 + 방진마스크 + (보안경 or 안면보호대)
  WorkTypeGear(
    name: '분진작업',
    icon: Icons.air,
    requiredGroups: [
      ['helmet'],
      ['safety_shoes'],
      ['safety_gloves'],
      ['gaiters'],
      ['dust_mask'],
      ['safety_glasses', 'face_shield'], // 둘 중 하나
    ],
  ),
  // 화학작업: 안전모·안전화·내화학장갑·각반·보호복·방독마스크 + (보안경 or 안면보호대)
  WorkTypeGear(
    name: '화학작업',
    icon: Icons.science,
    requiredGroups: [
      ['helmet'],
      ['safety_shoes'],
      ['chemical_gloves'],
      ['gaiters'],
      ['protective_suit'],
      ['gas_mask'],
      ['safety_glasses', 'face_shield'], // 둘 중 하나
    ],
  ),
  // 용접작업: 기본(안전모·안전화·용접장갑·용접각반) + 보안면 조건 분기 (isWelding)
  WorkTypeGear(
    name: '용접작업',
    icon: Icons.local_fire_department,
    isWelding: true,
    requiredGroups: [
      ['helmet'],
      ['safety_shoes'],
      ['welding_gloves'],
      ['welding_gaiters'],
    ],
  ),
];

class InspectionWorktypeScreen extends StatefulWidget {
  const InspectionWorktypeScreen({super.key});

  @override
  State<InspectionWorktypeScreen> createState() =>
      _InspectionWorktypeScreenState();
}

class _InspectionWorktypeScreenState extends State<InspectionWorktypeScreen> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inspection 모드',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '점검할 작업 종류를 선택하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: kWorkTypes.length,
                itemBuilder: (context, index) {
                  final work = kWorkTypes[index];
                  final selected = selectedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIndex = index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEDE7F6)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            work.icon,
                            size: 26,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  work.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  work.displayItems,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: selectedIndex == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InspectionWorkerScreen(
                              workType: kWorkTypes[selectedIndex!],
                            ),
                          ),
                        );
                      },
                child: const Text('다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
