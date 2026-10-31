import 'package:flutter/material.dart';
import 'inspection_worker_screen.dart';

class InspectionWorkScreen extends StatefulWidget {
  const InspectionWorkScreen({super.key});

  @override
  State<InspectionWorkScreen> createState() => _InspectionWorkScreenState();
}

class _InspectionWorkScreenState extends State<InspectionWorkScreen> {
  int selected = 0; // 선택된 작업 (0=고소)

  // Inspection 작업 종류 (4종) — 일반작업(공통 4종)은 게이트에서 확인하므로 제외
  // 'name'은 ppe_rules.dart의 작업 판정(고소/분진/화학/용접)과 맞춰야 함
  // 'ppe'는 카드 설명 문구 (ppe_rules.dart의 필수 장비 기준)
  final List<Map<String, dynamic>> works = const [
    {'icon': Icons.stairs, 'name': '고소작업', 'ppe': '공통 4종 + 안전대·안전고리'},
    {'icon': Icons.air, 'name': '분진작업', 'ppe': '공통 4종 + 방진마스크·보안경/안면보호대'},
    {'icon': Icons.science, 'name': '화학작업', 'ppe': '내화학장갑·보호복·방독마스크·보안경…'},
    {
      'icon': Icons.local_fire_department,
      'name': '용접작업',
      'ppe': '보안면·용접장갑·용접각반·안전화…',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, size: 26),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Inspection 모드',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 34),
                child: Text(
                  '점검할 작업 종류를 선택하세요',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
              ),
              const SizedBox(height: 16),

              // 작업 카드 목록
              Expanded(
                child: ListView.separated(
                  itemCount: works.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final w = works[i];
                    final bool isSel = selected == i;
                    return GestureDetector(
                      onTap: () => setState(() => selected = i),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F5FC),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF7F77DD)
                                : const Color(0xFFE0DEF5),
                            width: isSel ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              w['icon'],
                              size: 24,
                              color: const Color(0xFF534AB7),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w['name'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    w['ppe'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF7F77DD),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // 다음 버튼
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InspectionWorkerScreen(
                        workType: works[selected]['name'],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '다음',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
