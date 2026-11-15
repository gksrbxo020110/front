import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  static const String baseUrl = 'http://54.116.173.205:8081';

  // 로그인
  static Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/users/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('로그인 실패: ${response.statusCode}');
    }
  }

  // 지금 로그인한 관리자 비밀번호 확인 (Gate 관리자 확인·나가기 잠금용)
  // 저장된 관리자 아이디 + 입력 비번으로 로그인 시도 → 성공하면 맞음
  // true = 맞음 / false = 틀림 / null = 서버 연결 실패
  static Future<bool?> verifyMyPassword(String password) async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.isEmpty) return false;
      await login(userId: userId, password: password);
      return true; // login이 예외 없이 끝나면 비번 맞음
    } catch (e) {
      // 비번 틀림(401 등) → Exception. 서버 연결 실패도 여기로 옴
      // 비번 틀림과 서버 오류 구분이 어려우면 둘 다 false 처리 (안전)
      final msg = e.toString();
      if (msg.contains('500') || msg.contains('503') || msg.contains('SocketException')) {
        return null; // 서버 문제
      }
      return false; // 비번 틀림
    }
  }

  // 이메일 인증 코드 발송
  static Future<void> sendEmailCode({
    required String email,
    String purpose = 'SIGNUP',
  }) async {
    final url = Uri.parse('$baseUrl/api/email/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'purpose': purpose}),
    );

    if (response.statusCode != 200) {
      throw Exception('이메일 발송 실패: ${response.statusCode}');
    }
  }

  // 이메일 인증 코드 검증
  static Future<void> verifyEmailCode({
    required String email,
    required String code,
    String purpose = 'SIGNUP',
  }) async {
    final url = Uri.parse('$baseUrl/api/email/verify');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'purpose': purpose}),
    );

    if (response.statusCode != 200) {
      throw Exception('인증 실패: ${response.statusCode}');
    }
  }

  // 회원가입
  static Future<void> signup({
    required String userId,
    required String password,
    required String name,
    required String nickname,
    required String email,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/api/users/signup');
    final response = await http.post(
      url,
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

    if (response.statusCode != 200 && response.statusCode != 201) {
      final msg = utf8.decode(response.bodyBytes);
      throw Exception('회원가입 실패: $msg');
    }
  }

  // 아이디 찾기
  static Future<String> findId({required String email}) async {
    final url = Uri.parse('$baseUrl/api/users/find-id');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('아이디 찾기 실패: ${response.statusCode}');
    }
  }

  // 비밀번호 재설정 (아이디 + 인증된 이메일 + 새 비밀번호)
  static Future<void> resetPassword({
    required String userId,
    required String email,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/api/users/reset-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'email': email,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('비밀번호 재설정 실패: ${response.statusCode}');
    }
  }

  // 비밀번호 변경 (로그인 필요 → 토큰 헤더)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/users/change-password');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('비밀번호 변경 실패: ${response.statusCode}');
    }
  }

  // 회원 탈퇴 (로그인 필요 → 토큰 헤더)
  static Future<void> deleteAccount({required String password}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/users/me');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('회원 탈퇴 실패: ${response.statusCode}');
    }
  }

  // 내 정보 조회 (로그인 필요 → 토큰 헤더)
  // 성공 시 {name, role, siteId, siteName} 반환 (siteId/siteName은 소속 없으면 null)
  static Future<Map<String, dynamic>> getMyInfo() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/users/me');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('내 정보 조회 실패: ${response.statusCode}');
    }
  }

  // 아이디 중복 확인
  // true=사용가능, false=중복
  static Future<bool> checkId({required String userId}) async {
    final url = Uri.parse('$baseUrl/api/users/check-id?userId=$userId');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as bool;
    } else {
      throw Exception('아이디 중복 확인 실패: ${response.statusCode}');
    }
  }

  // 닉네임 중복 확인
  // true=사용가능, false=중복
  static Future<bool> checkNickname({required String nickname}) async {
    final url = Uri.parse(
      '$baseUrl/api/users/check-nickname?nickname=$nickname',
    );
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as bool;
    } else {
      throw Exception('닉네임 중복 확인 실패: ${response.statusCode}');
    }
  }

  // 현장 생성 (관리자, 로그인 필요 → 토큰 헤더)
  // 성공 시 {siteCode, siteName, address} 반환
  static Future<Map<String, dynamic>> createSite({
    required String siteName,
    required String address,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'siteName': siteName, 'address': address}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('현장 생성 실패: ${response.statusCode}');
    }
  }

  // 현장 참여 (노동자, 로그인 필요 → 토큰 헤더)
  // 6자리 현장 코드로 참여, 성공 시 {siteCode, siteName, address} 반환
  static Future<Map<String, dynamic>> joinSite({
    required String siteCode,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/join');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'siteCode': siteCode}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('현장 참여 실패: ${response.statusCode}');
    }
  }

  // 내 현장 조회 (로그인 필요 → 토큰 헤더)
  // 소속 현장 있으면 {siteCode, siteName, address} 반환, 없으면 null
  static Future<Map<String, dynamic>?> getMySite() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/my');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      if (body.trim().isEmpty || body.trim() == 'null') {
        return null;
      }
      return jsonDecode(body);
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      return null;
    } else {
      throw Exception('내 현장 조회 실패: ${response.statusCode}');
    }
  }

  // 현장 노동자 수 조회 (관리자, 로그인 필요 → 토큰 헤더)
  // 성공 시 노동자 수(정수) 반환
  static Future<int> getWorkerCount() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/workers/count');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as int;
    } else {
      throw Exception('노동자 수 조회 실패: ${response.statusCode}');
    }
  }

  // 현장 나가기 (노동자, 로그인 필요 → 토큰 헤더)
  static Future<void> leaveSite() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/leave');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('현장 나가기 실패: ${response.statusCode}');
    }
  }

  // 현장 삭제 (관리자, 로그인 필요 → 토큰 헤더)
  // 혼자 남았을 때만 삭제 가능 (소속 노동자 없어야 함)
  static Future<void> deleteSite() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('현장 삭제 실패: ${response.statusCode}');
    }
  }

  // ===== Inspection 노동자 선택용 =====

  // 소속 현장 노동자 목록 조회 (관리자, Inspection 노동자 선택용)
  // 성공 시 [{userId, name, nickname}, ...] 반환
  static Future<List<Map<String, dynamic>>> getSiteWorkers() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/workers');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('노동자 목록 조회 실패: ${response.statusCode}');
    }
  }

  // 노동자 검색 (관리자, 닉네임으로)
  // 성공 시 {userId, name, nickname} 반환, 없으면 null
  static Future<Map<String, dynamic>?> searchWorker({
    required String nickname,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      '$baseUrl/api/sites/workers/search?nickname=$nickname',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      if (body.trim().isEmpty || body.trim() == 'null') return null;
      return jsonDecode(body);
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      return null; // 검색 결과 없음
    } else {
      throw Exception('노동자 검색 실패: ${response.statusCode}');
    }
  }

  // QR 발급/재발급 (노동자, 로그인 필요 → 토큰 헤더)
  // validDays 안 보내면 서버 기본 유효기간 사용
  // 성공 시 {userId, token, issuedAt, expireAt, qrImageBase64} 반환
  static Future<Map<String, dynamic>> issueQr({int? validDays}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/qr/issue');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(validDays != null ? {'validDays': validDays} : {}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('QR 발급 실패: ${response.statusCode}');
    }
  }

  // 내 QR 조회 (노동자, 로그인 필요 → 토큰 헤더)
  // 유효한 QR 있으면 {userId, token, issuedAt, expireAt, qrImageBase64} 반환
  // 만료/없음이면 null 반환 (화면에서 "발급 필요"로 처리)
  static Future<Map<String, dynamic>?> getMyQr() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/qr/my');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      if (body.trim().isEmpty || body.trim() == 'null') {
        return null;
      }
      return jsonDecode(body);
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      // QR 만료 또는 없음
      return null;
    } else {
      throw Exception('내 QR 조회 실패: ${response.statusCode}');
    }
  }

  // QR 검증 (게이트에서 스캔한 토큰이 유효한지 확인, 관리자 토큰 필요)
  // 성공 시 {valid, userId, name, siteId, message} 반환
  static Future<Map<String, dynamic>> verifyQr({
    required String qrToken,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/qr/verify');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'token': qrToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('QR 검증 실패: ${response.statusCode}');
    }
  }

  // ===== 미착용 감지 저장 (게이트/순찰 공통) =====

  // 1단계: S3 업로드용 Presigned URL 발급
  // 성공 시 {uploadUrl, s3Key} 반환
  static Future<Map<String, String>> getS3UploadUrl() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/s3/upload-url');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'uploadUrl': data['uploadUrl'] as String,
        's3Key': data['s3Key'] as String,
      };
    } else {
      throw Exception('업로드 URL 발급 실패: ${response.statusCode}');
    }
  }

  // 2단계: 캡처 이미지를 S3에 직접 PUT 업로드
  // uploadUrl은 1단계에서 받은 것, imageBytes는 jpg 바이트
  static Future<void> uploadImageToS3({
    required String uploadUrl,
    required List<int> imageBytes,
  }) async {
    // presigned URL은 서버가 image/jpeg로 서명했으므로 Content-Type 꼭 맞춰야 함
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: imageBytes,
    );

    if (response.statusCode != 200) {
      throw Exception('S3 업로드 실패: ${response.statusCode}');
    }
  }

  // 3단계: 감지 결과(미착용 데이터) 저장
  // 성공 시 {success, recordId} 반환
  static Future<Map<String, dynamic>> saveDetection({
    required String clientUuid,
    required String targetUserId,
    String? inspectorUserId,
    required int? siteId,
    required String detectionMode, // "GATE" 또는 "INSPECTION"
    String? workType,
    String? s3Key,
    required List<Map<String, dynamic>> items,
    // items 각 원소: {ppeId: int, worn: bool, confidence: double}
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/detections');
    final response = await http.post(
      url,
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

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('감지 저장 실패: ${response.statusCode}');
    }
  }

  // ===== 대시보드 =====

  // 관리자 대시보드 조회 (소속 현장 컬러링 현황 + 노동자 안전등급 목록)
  // 성공 시 {siteId, siteName, greenCount, yellowCount, redCount,
  //          todayViolationCount, workers: [...]} 반환
  static Future<Map<String, dynamic>> getManagerDashboard() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/dashboard/manager');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('관리자 대시보드 조회 실패: ${response.statusCode}');
    }
  }

  // 관리자가 특정 노동자 상세 조회 (안전등급 + 미착용 이력)
  // 성공 시 {userId, name, violationCount, grade, history: [...], notifications: [...]}
  static Future<Map<String, dynamic>> getWorkerDetailByAdmin({
    required String targetUserId,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/dashboard/worker/$targetUserId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('노동자 상세 조회 실패: ${response.statusCode}');
    }
  }

  // 노동자 소속 해제 (관리자)
  static Future<void> removeWorker({required String targetUserId}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/sites/workers');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'targetUserId': targetUserId}),
    );

    if (response.statusCode != 200) {
      throw Exception('노동자 소속 해제 실패: ${response.statusCode}');
    }
  }

  // S3 조회용 URL 발급 (미착용 캡처 이미지 보기)
  // s3Key로 5분 유효한 조회 URL 받음
  static Future<String?> getS3ViewUrl({required String s3Key}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/s3/view-url?s3Key=$s3Key');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['viewUrl'] as String?;
    } else {
      return null;
    }
  }

  // 노동자 본인 대시보드 조회 (본인 안전등급 + 미착용 이력)
  // 성공 시 {userId, name, violationCount, grade, history: [...], notifications: [...]}
  static Future<Map<String, dynamic>> getWorkerDashboard() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/dashboard/worker');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('노동자 대시보드 조회 실패: ${response.statusCode}');
    }
  }

  // FCM 토큰 서버 전송 (로그인 후, 푸시 알림 받기 위해)
  static Future<void> sendFcmToken({required String fcmToken}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/users/fcm-token');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcmToken': fcmToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('FCM 토큰 전송 실패: ${response.statusCode}');
    }
  }

  // 노동자 출입 차단 해제 (관리자)
  static Future<void> unblockWorker({required String targetUserId}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      '$baseUrl/api/dashboard/worker/$targetUserId/unblock',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('출입 차단 해제 실패: ${response.statusCode}');
    }
  }

  // ===== 알림 =====

  // 내 알림 이력 조회 (최신순)
  // 성공 시 [{notificationId, recordId, message, sentAt, isRead}, ...]
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/notifications');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('알림 조회 실패: ${response.statusCode}');
    }
  }

  // 안 읽은 알림 개수 (뱃지용)
  static Future<int> getUnreadCount() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/notifications/unread-count');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['unreadCount'] ?? 0) as int;
    } else {
      throw Exception('안 읽은 알림 개수 조회 실패: ${response.statusCode}');
    }
  }

  // 특정 알림 읽음 처리
  static Future<void> markNotificationRead({
    required int notificationId,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/notifications/$notificationId/read');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('알림 읽음 처리 실패: ${response.statusCode}');
    }
  }

  // 알림 설정 조회 (현재 ON/OFF)
  // 성공 시 enabled(bool) 반환
  static Future<bool> getNotificationSetting() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/notifications/settings');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['enabled'] ?? true) as bool;
    } else {
      throw Exception('알림 설정 조회 실패: ${response.statusCode}');
    }
  }

  // 알림 설정 변경 (ON/OFF)
  // 성공 시 변경된 enabled(bool) 반환
  static Future<bool> updateNotificationSetting({required bool enabled}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$baseUrl/api/notifications/settings');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'enabled': enabled}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['enabled'] ?? enabled) as bool;
    } else {
      throw Exception('알림 설정 변경 실패: ${response.statusCode}');
    }
  }
}
