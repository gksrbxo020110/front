// best.tflite 모델의 클래스(라벨) 정보
class PpeLabels {
  // 모델 입력 크기
  static const int inputSize = 640;

  // 신뢰도 임계값 (이 값 이상만 감지로 인정)
  static const double confThreshold = 0.4;

  // 클래스 16개 (인덱스 순서 = 모델 출력 순서)
  static const List<String> labels = [
    'chemical_gloves', // 0  화학용 장갑
    'dust_mask', // 1  방진 마스크
    'face_shield', // 2  안면 보호구
    'gaiters', // 3  각반
    'gas_mask', // 4  방독 마스크
    'helmet', // 5  안전모 (턱끈 O)
    'helmet_nostrap', // 6  안전모 (턱끈 X)
    'protective_suit', // 7  보호복
    'safety_glasses', // 8  보안경
    'safety_gloves', // 9  안전 장갑
    'safety_harness', // 10 안전대
    'safety_hook', // 11 안전 고리
    'safety_shoes', // 12 안전화
    'welding_gaiters', // 13 용접용 각반
    'welding_gloves', // 14 용접용 장갑
    'welding_shield', // 15 용접 면
  ];

  // 클래스 한글 이름 (화면 표시용)
  static const Map<String, String> koreanNames = {
    'chemical_gloves': '화학용 장갑',
    'dust_mask': '방진 마스크',
    'face_shield': '안면 보호구',
    'gaiters': '각반',
    'gas_mask': '방독 마스크',
    'helmet': '안전모',
    'helmet_nostrap': '안전모(턱끈 미착용)',
    'protective_suit': '보호복',
    'safety_glasses': '보안경',
    'safety_gloves': '안전 장갑',
    'safety_harness': '안전대',
    'safety_hook': '안전 고리',
    'safety_shoes': '안전화',
    'welding_gaiters': '용접용 각반',
    'welding_gloves': '용접용 장갑',
    'welding_shield': '용접 면',
  };

  // 인덱스로 라벨 이름 얻기
  static String labelAt(int index) {
    if (index < 0 || index >= labels.length) return 'unknown';
    return labels[index];
  }

  // 인덱스로 한글 이름 얻기
  static String koreanAt(int index) {
    final label = labelAt(index);
    return koreanNames[label] ?? label;
  }
}
