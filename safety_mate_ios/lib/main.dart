import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'screens/login_screen.dart';

void main() async {
  // Firebase 초기화 전에 Flutter 바인딩 준비
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화 (GoogleService-Info.plist 읽어서 연결)
  await Firebase.initializeApp();

  runApp(const SafetyMateApp());
}

class SafetyMateApp extends StatelessWidget {
  const SafetyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 스마트 안전 메이트',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
