import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 토큰·유저아이디·역할을 안전하게 저장·읽기·삭제하는 헬퍼
class TokenStorage {
  // 보안 저장소 (iOS Keychain에 암호화 저장)
  static const _storage = FlutterSecureStorage();

  // 저장 이름표
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'user_role';

  // 토큰 저장 (로그인 성공 시 서버가 준 토큰을 저장)
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // 토큰 읽기 (서버 요청 시 꺼내 씀). 없으면 null
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // 유저 아이디 저장 (로그인 시 함께 저장, Inspection inspectorUserId 등에 사용)
  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  // 유저 아이디 읽기. 없으면 null
  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // 역할 저장 (로그인 시 함께 저장, "ADMIN"/"WORKER")
  static Future<void> saveRole(String role) async {
    await _storage.write(key: _roleKey, value: role);
  }

  // 역할 읽기. 없으면 null
  static Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  // 토큰 삭제 (로그아웃·회원탈퇴 시)
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // 전체 삭제 (혹시 다른 저장 정보도 다 지울 때)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
