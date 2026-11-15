import 'package:flutter/material.dart';

// 앱 전체에서 쓰는 색을 여기 모아둠 (피그마 디자인 규칙을 코드로)
class AppColors {
  static const Color primary = Color(0xFF1A1A1A); // 주요 버튼 (검정)
  static const Color background = Color(0xFFFFFFFF); // 배경 (흰색)
  static const Color textPrimary = Color(0xFF1A1A1A); // 본문 글씨
  static const Color textSecondary = Color(0xFF6B7280); // 보조 글씨 (회색)
  static const Color border = Color(0xFFE5E7EB); // 테두리 (연회색)

  // 안전 신호색 (컬러링 등급)
  static const Color safe = Color(0xFF2E7D32); // 초록 (안전/그린)
  static const Color warning = Color(0xFFF9A825); // 노랑 (주의/옐로)
  static const Color danger = Color(0xFFD32F2F); // 빨강 (위험/레드)
}

// 앱 전체 테마 (버튼·입력창 기본 모양)
final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  primaryColor: AppColors.primary,
  fontFamily: 'Pretendard', // 나중에 폰트 넣으면 적용됨 (지금은 기본 폰트로 나옴)
  // 주요 버튼 스타일 (검정 꽉 찬 버튼) - 로그인·가입 등에 자동 적용
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52), // 가로 꽉 차고 높이 52
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // 모서리 둥글게 (버튼 8~12)
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  // 입력창 스타일 - 모든 입력 필드에 자동 적용
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), // 입력 필드 모서리 8
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    hintStyle: const TextStyle(color: AppColors.textSecondary),
  ),
);
