import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'main_tab_screen.dart';
import 'worker_main_tab_screen.dart';

// ── 백그라운드/종료 상태에서 메시지 도착 시 호출 (top-level 함수여야 함) ──
// (이 상태에선 안드로이드가 알림을 자동으로 띄워줌)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(
    '🔔 [백그라운드] ${message.notification?.title} / ${message.notification?.body}',
  );
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ── 어느 화면에서든 화면 이동할 수 있게 하는 열쇠 (main.dart에 등록) ──
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 이번 실행에서 로그인했는지 (로그인 성공 시 true)
  static bool _loggedInThisSession = false;

  // 로그인 전에 알림을 눌렀으면 true → 로그인 후 알림 탭으로 이동
  static bool _pendingOpenNotifications = false;

  // ── 포그라운드 알림용 (앱 켜져 있을 때 직접 띄움) ──
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // 안드로이드 알림 채널 정보 (중요도 high → 화면 상단에 팝업으로 뜸)
  // ※ 채널은 첫 알림을 띄울 때 패키지가 자동으로 만들어줌
  static const String _channelId = 'ppe_alert_channel';
  static const String _channelName = '보호구 미착용 알림';
  static const String _channelDesc = '보호구 미착용 감지 시 받는 알림';

  // ── 앱 시작 시 1회 호출: 권한 요청 + 리스너 등록 + 토큰 확인 ──
  static Future<void> init() async {
    // 1) 알림 권한 요청 (안드로이드 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('🔔 알림 권한: ${settings.authorizationStatus}');

    // 2) 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3) 포그라운드 알림 준비 (로컬 알림 초기화)
    //    실패해도 앱은 계속 돌아가야 하므로 try-catch
    try {
      await _initLocalNotifications();
    } catch (e) {
      print('⚠️ 로컬 알림 초기화 실패 (앱은 계속 진행): $e');
    }

    // 4) 포그라운드(앱 켜져 있을 때) 메시지 수신 → 직접 알림 띄우기
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        '🔔 [포그라운드] ${message.notification?.title} / ${message.notification?.body}',
      );
      _showForegroundNotification(message);
    });

    // 5) 백그라운드 상태에서 알림 탭해서 앱 열었을 때 → 알림 탭으로 이동
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 [알림 탭] ${message.notification?.title}');
      _onNotificationTapped();
    });

    // 6) 앱이 완전히 꺼져 있다가 알림 탭으로 켜졌을 때 → 로그인 후 알림 탭으로
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        print('🔔 [종료 상태에서 알림 탭으로 실행] ${initial.notification?.title}');
        _pendingOpenNotifications = true;
      }
    } catch (e) {
      print('⚠️ 초기 알림 확인 실패: $e');
    }

    // 7) 현재 FCM 토큰 출력 (Firebase 콘솔 테스트용으로 복사할 것)
    //    토큰 실패해도 앱은 계속 돌아가야 하므로 try-catch로 감쌈
    try {
      final token = await _messaging.getToken();
      print('🟢🟢🟢 내 FCM 토큰: $token');
    } catch (e) {
      print('⚠️ FCM 토큰 발급 실패 (앱은 계속 진행): $e');
    }

    // 8) 토큰 갱신 시 서버에 다시 저장
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM 토큰 갱신됨');
      ApiService.saveFcmToken(newToken);
    });
  }

  // ── 로컬 알림 초기화 ──
  static Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 포그라운드에서 띄운 알림을 탭했을 때 → 알림 탭으로 이동
        print('🔔 [로컬 알림 탭] payload: ${response.payload}');
        _onNotificationTapped();
      },
    );
  }

  // ── 알림 탭 처리: 역할에 맞는 알림 탭으로 이동 ──
  static Future<void> _onNotificationTapped() async {
    final token = await ApiService.getToken();
    final role = await ApiService.getRole();
    final nav = navigatorKey.currentState;

    // 로그인 전이면 예약만 해두고, 로그인 후 이동
    if (!_loggedInThisSession ||
        token == null ||
        token.isEmpty ||
        role == null ||
        nav == null) {
      print('🔔 로그인 전 → 로그인 후 알림 탭으로 이동 예약');
      _pendingOpenNotifications = true;
      return;
    }

    Widget target;
    if (role == 'ADMIN') {
      target = const MainTabScreen(
        initialIndex: MainTabScreen.notificationTabIndex,
      );
    } else if (role == 'WORKER') {
      target = const WorkerMainTabScreen(
        initialIndex: WorkerMainTabScreen.notificationTabIndex,
      );
    } else {
      return;
    }

    // 쌓여 있던 화면 정리하고 알림 탭으로
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  // ── 로그인 화면에서 호출: 로그인 전에 알림 눌렀었는지 확인 (확인하면 초기화) ──
  static bool consumePendingOpen() {
    final pending = _pendingOpenNotifications;
    _pendingOpenNotifications = false;
    return pending;
  }

  // ── 포그라운드 메시지를 폰 알림으로 띄우기 ──
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          '안전 알림';
      final body =
          message.notification?.body ?? message.data['body']?.toString() ?? '';

      // 알림마다 다른 id (같은 id면 이전 알림을 덮어씀)
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000;

      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data['recordId']?.toString(),
      );
    } catch (e) {
      print('⚠️ 포그라운드 알림 표시 실패: $e');
    }
  }

  // ── 로그인 성공 후 호출: 토큰을 서버에 저장 ──
  static Future<void> registerTokenToServer() async {
    // 로그인 성공 직후에만 불리므로 여기서 "이번 실행 로그인됨" 표시
    _loggedInThisSession = true;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final ok = await ApiService.saveFcmToken(token);
        print(ok ? '✅ FCM 토큰 서버 저장 성공' : '❌ FCM 토큰 서버 저장 실패');
      }
    } catch (e) {
      print('⚠️ registerTokenToServer 실패: $e');
    }
  }
}
