// PPE 감지 클래스 (팀장 노션 순서표 기준, 순서 중요!)
// 인덱스 0~15, 모델 출력 순서와 정확히 일치해야 함
const List<String> ppeLabels = [
  'chemical_gloves', // 0
  'dust_mask', // 1
  'face_shield', // 2
  'gaiters', // 3
  'gas_mask', // 4
  'helmet', // 5
  'helmet_nostrap', // 6
  'protective_suit', // 7
  'safety_glasses', // 8
  'safety_gloves', // 9
  'safety_harness', // 10
  'safety_hook', // 11
  'safety_shoes', // 12
  'welding_gaiters', // 13
  'welding_gloves', // 14
  'welding_shield', // 15
];

// 한글 이름 (화면 표시용)
const Map<String, String> ppeLabelsKo = {
  'chemical_gloves': '화학용 장갑',
  'dust_mask': '방진 마스크',
  'face_shield': '안면 보호구',
  'gaiters': '각반',
  'gas_mask': '방독 마스크',
  'helmet': '안전모',
  'helmet_nostrap': '안전모(끈 미착용)',
  'protective_suit': '보호복',
  'safety_glasses': '보안경',
  'safety_gloves': '안전 장갑',
  'safety_harness': '안전대',
  'safety_hook': '안전 고리',
  'safety_shoes': '안전화',
  'welding_gaiters': '용접용 각반',
  'welding_gloves': '용접용 장갑',
  'welding_shield': '용접 마스크',
};
