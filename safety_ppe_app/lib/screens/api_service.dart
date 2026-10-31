import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart'; // 서버 주소 (깃허브에 안 올림)

class ApiService {
  // 팀장 서버 주소 → server_config.dart에서 가져옴 (깃허브 공개용으로 분리)
  static const String baseUrl = serverBaseUrl;

  // ══════════════════ 인증 ══════════════════

  // ── 이메일 인증코드 발송 ──
  static Future<bool> sendEmailCode(String email, String purpose) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'purpose': purpose}),
    );
    return res.statusCode == 200;
  }

  // ── 이메일 인증코드 확인 ──
  static Future<bool> verifyEmailCode(
    String email,
    String code,
    String purpose,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/email/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'purpose': purpose}),
    );
    return res.statusCode == 200;
  }

  // ── 회원가입 ──
  static Future<Map<String, dynamic>> signup({
    required String userId,
    required String password,
    required String name,
    required String nickname,
    required String email,
    required String role,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'password': password,
        'name': name,
        'nickname': nickname,
        'email': email,
        'role': role,
      }),
    );
    return {
      'success': res.statusCode == 200,
      'statusCode': res.statusCode,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 로그인 ──
  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'token': data['token'],
        'userId': data['userId'],
        'role': data['role'],
      };
    }
    return {
      'success': false,
      'statusCode': res.statusCode,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 아이디 찾기 (인증 없이 이메일만) ──
  static Future<Map<String, dynamic>> findId(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/find-id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 비밀번호 재설정 (이메일 인증 후, 로그인 전) ──
  // 서버 ResetPasswordRequest = {userId, email, newPassword} (아이디 + 이메일 둘 다 확인)
  static Future<Map<String, dynamic>> resetPassword(
    String userId,
    String email,
    String newPassword,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'email': email,
        'newPassword': newPassword,
      }),
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 비밀번호 변경 (로그인 후, 토큰) ──
  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 회원 탈퇴 (토큰) ──
  static Future<Map<String, dynamic>> deleteAccount(String password) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 아이디 중복 확인 ──
  static Future<bool?> checkUserId(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/check-id?userId=$userId'),
    );
    if (res.statusCode == 200) {
      // true=사용가능, false=중복
      return utf8.decode(res.bodyBytes).trim() == 'true';
    }
    return null; // 에러
  }

  // ── 닉네임 중복 확인 ──
  static Future<bool?> checkNickname(String nickname) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/check-nickname?nickname=$nickname'),
    );
    if (res.statusCode == 200) {
      return utf8.decode(res.bodyBytes).trim() == 'true';
    }
    return null;
  }

  // ══════════════════ 현장 ══════════════════

  // ── 현장 생성 (관리자, 토큰) ──
  static Future<Map<String, dynamic>> createSite(
    String siteName,
    String address,
  ) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/sites'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'siteName': siteName, 'address': address}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'siteCode': data['siteCode'],
        'siteName': data['siteName'],
        'address': data['address'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 현장 참여 (노동자, 토큰) ──
  static Future<Map<String, dynamic>> joinSite(String siteCode) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/sites/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'siteCode': siteCode}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'siteCode': data['siteCode'],
        'siteName': data['siteName'],
        'address': data['address'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 현장 나가기 (노동자, 토큰) ──
  static Future<Map<String, dynamic>> leaveSite() async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/sites/leave'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 내 현장 조회 (토큰) ──
  static Future<Map<String, dynamic>> getMySite() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/sites/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'siteCode': data['siteCode'],
        'siteName': data['siteName'],
        'address': data['address'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 노동자 검색 (관리자, 토큰) ──
  static Future<Map<String, dynamic>> searchWorker(String nickname) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/sites/workers/search?nickname=$nickname'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'userId': data['userId'],
        'name': data['name'],
        'nickname': data['nickname'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 노동자 소속 해제 (관리자, 토큰) ──
  static Future<Map<String, dynamic>> removeWorker(String targetUserId) async {
    final token = await getToken();
    print('🔴 removeWorker 요청 targetUserId: $targetUserId');
    final res = await http.delete(
      Uri.parse('$baseUrl/api/sites/workers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'targetUserId': targetUserId}),
    );
    print('🔴 removeWorker status: ${res.statusCode}');
    print('🔴 removeWorker body: ${utf8.decode(res.bodyBytes)}');
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 현장 삭제 (관리자, 토큰) ──
  static Future<Map<String, dynamic>> deleteSite() async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/sites'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ── 노동자 수 조회 (관리자, 토큰) ──
  static Future<int> getWorkerCount() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/sites/workers/count'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      // 응답이 숫자 하나 (예: 5)
      return int.tryParse(utf8.decode(res.bodyBytes).trim()) ?? 0;
    }
    return 0;
  }

  // ── 현장 노동자 목록 조회 (관리자, 토큰) ──
  // GET /api/sites/workers → [{userId, name, nickname, entryBlocked}, ...]
  // entryBlocked: 출입 차단 여부 (서버 WorkerResponse, RED 3회 시 자동 차단)
  static Future<List<Map<String, dynamic>>> getSiteWorkerList() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/sites/workers'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data
          .map<Map<String, dynamic>>(
            (w) => {
              'userId': w['userId'],
              'name': w['name'],
              'nickname': w['nickname'],
              'entryBlocked': w['entryBlocked'] == true,
            },
          )
          .toList();
    }
    return [];
  }

  // ── 내 정보 조회 (토큰) ──
  static Future<Map<String, dynamic>> getMyInfo() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'name': data['name'],
        'role': data['role'],
        'siteId': data['siteId'],
        'siteName': data['siteName'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }
  // ══════════════════ 대시보드 ══════════════════

  // ── 관리자 대시보드 조회 (관리자, 토큰) ──
  // GET /api/dashboard/manager → ManagerDashboardResponse
  static Future<Map<String, dynamic>> getManagerDashboard() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/manager'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'siteId': data['siteId'],
        'siteName': data['siteName'],
        'greenCount': data['greenCount'],
        'yellowCount': data['yellowCount'],
        'redCount': data['redCount'],
        'todayViolationCount': data['todayViolationCount'],
        // workers: [{userId, name, nickname, violationCount, grade}, ...]
        'workers': data['workers'] ?? [],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 노동자 대시보드 조회 (노동자 본인, 토큰) ──
  // GET /api/dashboard/worker → WorkerDashboardResponse
  static Future<Map<String, dynamic>> getWorkerDashboard() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/worker'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'userId': data['userId'],
        'name': data['name'],
        'violationCount': data['violationCount'] ?? 0,
        'grade': data['grade']?.toString() ?? 'GREEN',
        // history: [{recordId, detectedAt, detectionMode, workType, summary, notWornItems, s3Key}, ...]
        'history': data['history'] ?? [],
        // notifications: [{notificationId, recordId, message, sentAt, isRead}, ...]
        'notifications': data['notifications'] ?? [],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 특정 노동자 대시보드 조회 (관리자가 특정 노동자 상세, 토큰) ──
  // GET /api/dashboard/worker/{targetUserId} → WorkerDashboardResponse
  static Future<Map<String, dynamic>> getWorkerDashboardById(
    String targetUserId,
  ) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/worker/$targetUserId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'userId': data['userId'],
        'name': data['name'],
        'violationCount': data['violationCount'] ?? 0,
        'grade': data['grade']?.toString() ?? 'GREEN',
        'history': data['history'] ?? [],
        'notifications': data['notifications'] ?? [],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── 노동자 출입 차단 해제 (관리자, 토큰) ──
  // POST /api/dashboard/worker/{targetUserId}/unblock → "출입 차단이 해제되었습니다."
  // 해제해도 등급(RED)·위반 건수는 그대로, 다시 위반하면 자동 재차단 (서버 설계)
  static Future<Map<String, dynamic>> unblockWorker(String targetUserId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/dashboard/worker/$targetUserId/unblock'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return {
      'success': res.statusCode == 200,
      'body': utf8.decode(res.bodyBytes),
    };
  }

  // ══════════════════ QR ══════════════════

  // ── 내 QR 조회 (토큰) ──
  // GET /api/qr/my → QrCodeResponse {userId, token, issuedAt, expireAt, qrImageBase64}
  static Future<Map<String, dynamic>> getMyQr() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/qr/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'userId': data['userId'],
        'token': data['token'],
        'issuedAt': data['issuedAt'],
        'expireAt': data['expireAt'],
        'qrImageBase64': data['qrImageBase64'],
      };
    }
    // QR 없음/만료 등 → 서버가 메시지 반환
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── QR 발급/갱신 (토큰) ──
  // POST /api/qr/issue  Body: {validDays}(null이면 서버 기본값) → QrCodeResponse
  static Future<Map<String, dynamic>> issueQr({int? validDays}) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/qr/issue'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'validDays': validDays}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'userId': data['userId'],
        'token': data['token'],
        'issuedAt': data['issuedAt'],
        'expireAt': data['expireAt'],
        'qrImageBase64': data['qrImageBase64'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── QR 검증 (게이트 스캔) ──
  // POST /api/qr/verify  Body: {token} → VerifyQrResponse {valid, userId, name, siteId, message}
  // ※ 서버가 인증 요구(403)해서 Authorization 헤더 추가함 (게이트는 관리자 로그인 상태로 운영)
  static Future<Map<String, dynamic>> verifyQr(String qrToken) async {
    final authToken = await getToken();
    print('🟣 verifyQr 스캔한 토큰: $qrToken');
    final res = await http.post(
      Uri.parse('$baseUrl/api/qr/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'token': qrToken}),
    );
    print('🟣 verifyQr status: ${res.statusCode}');
    print('🟣 verifyQr body: ${utf8.decode(res.bodyBytes)}');
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'valid': data['valid'],
        'userId': data['userId'],
        'name': data['name'],
        'siteId': data['siteId'],
        'message': data['message'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }
  // ══════════════════ 알림 ══════════════════

  // ── 내 알림 이력 조회 (토큰, 최신순) ──
  // GET /api/notifications → List<NotificationResponse>
  static Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data
          .map<Map<String, dynamic>>(
            (n) => {
              'notificationId': n['notificationId'],
              'recordId': n['recordId'],
              'message': n['message'],
              'sentAt': n['sentAt'],
              // 서버 boolean isRead → JSON에선 "read"로 옴 (Lombok/Jackson 규칙)
              'isRead': n['isRead'] ?? n['read'] ?? false,
            },
          )
          .toList();
    }
    return [];
  }

  // ── 특정 알림 읽음 처리 (토큰) ──
  // PUT /api/notifications/{id}/read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    final token = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200;
  }

  // ── 알림 설정 조회 (토큰) ──
  // GET /api/notifications/settings → {userId, enabled}
  static Future<bool> getNotificationSetting() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications/settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['enabled'] == true;
    }
    return true; // 기본 ON
  }

  // ── 알림 설정 변경 (토큰) ──
  // PUT /api/notifications/settings {enabled} → {userId, enabled}
  static Future<bool> updateNotificationSetting(bool enabled) async {
    final token = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/api/notifications/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'enabled': enabled}),
    );
    return res.statusCode == 200;
  }

  // ══════════════════ FCM ══════════════════

  // ── FCM 토큰 서버 저장 (토큰) ──
  // POST /api/users/fcm-token  Body: {fcmToken}
  static Future<bool> saveFcmToken(String fcmToken) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/users/fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcmToken': fcmToken}),
    );
    final body = utf8.decode(res.bodyBytes);
    print('🔵 saveFcmToken status: ${res.statusCode} / body: $body');
    return res.statusCode == 200;
  }

  // ══════════════════ S3 / 감지 저장 ══════════════════

  // ── S3 업로드 URL 발급 (토큰) ──
  // POST /api/s3/upload-url → {uploadUrl, s3Key}
  static Future<Map<String, dynamic>> getS3UploadUrl() async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/s3/upload-url'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'uploadUrl': data['uploadUrl'],
        's3Key': data['s3Key'],
      };
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }

  // ── S3에 사진 직접 업로드 (PUT, 인증 불필요·URL에 서명 포함) ──
  // uploadUrl은 5분 유효, Content-Type: image/jpeg 필수
  static Future<bool> uploadImageToS3(
    String uploadUrl,
    List<int> imageBytes,
  ) async {
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: imageBytes,
    );
    return res.statusCode == 200;
  }

  // ── S3 조회 URL 발급 (토큰) — 대시보드/상세에서 사진 볼 때 ──
  // GET /api/s3/view-url?s3Key=xxx → {viewUrl}
  static Future<String?> getS3ViewUrl(String s3Key) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/s3/view-url?s3Key=$s3Key'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['viewUrl'];
    }
    return null;
  }

  // ── 감지 결과 저장 (토큰) ──
  // POST /api/detections → {success, recordId}
  // items: [{ppeId(YOLO클래스번호 0~15), worn(bool), confidence(double)}, ...]
  static Future<Map<String, dynamic>> saveDetection({
    required String clientUuid,
    required String targetUserId,
    String? inspectorUserId,
    required int siteId,
    required String detectionMode, // "GATE" or "INSPECTION"
    String? workType,
    String? s3Key,
    required List<Map<String, dynamic>> items,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/detections'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'clientUuid': clientUuid,
        'targetUserId': targetUserId,
        'inspectorUserId': inspectorUserId,
        'siteId': siteId,
        'detectionMode': detectionMode,
        'workType': workType,
        's3Key': s3Key,
        'items': items,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {'success': true, 'recordId': data['recordId']};
    }
    return {'success': false, 'body': utf8.decode(res.bodyBytes)};
  }
  // ══════════════════ 토큰 관리 ══════════════════

  static Future<void> saveToken(
    String token,
    String userId,
    String role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
  }
}
