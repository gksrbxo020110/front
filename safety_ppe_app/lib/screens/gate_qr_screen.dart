import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'gate_detection_screen.dart';
import 'api_service.dart';

class GateQrScreen extends StatefulWidget {
  const GateQrScreen({super.key});

  @override
  State<GateQrScreen> createState() => _GateQrScreenState();
}

class _GateQrScreenState extends State<GateQrScreen> {
  // QR 스캐너 컨트롤러 (게이트 감지 화면과 카메라를 나눠 쓰기 위해 직접 정지/시작)
  // 게이트: 전면 카메라 — 게이트 폰을 노동자 쪽으로 세워두고, 노동자가 QR을 화면 앞에 갖다 댐
  final MobileScannerController _scanner = MobileScannerController(
    facing: CameraFacing.front,
  );

  bool _handling = false; // 스캔~검증 중 중복 방지
  bool _verified = false; // 인증 성공 → 감지 화면으로 넘어가는 중
  bool _returning = false; // 감지 끝나고 돌아와서 QR 카메라 다시 켜는 중
  String? _failMsg; // 인증 실패 사유 (null이면 실패 아님)
  bool _failBlocked = false; // 출입 차단된 노동자로 실패했는지 (화면 모양 다르게)
  String _failName = ''; // 출입 차단된 노동자 이름

  // 같은 QR 연속 인식 방지 (감지 끝나고 돌아왔을 때 같은 사람 재인증 방지)
  String _lastCode = '';
  DateTime _lastCodeTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _sameCodeIgnoreMs = 3000;

  // 게이트 관리자(로그인한 사람)의 현장 번호
  // 서버 verifyQr는 현장 비교를 안 하므로 (QrService.verifyQr 확인) 앱에서 비교
  int? _mySiteId;

  @override
  void initState() {
    super.initState();
    _loadMySiteId(); // 화면 열릴 때 한 번만
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  // 관리자 현장 번호 불러오기 (실패하면 null 유지)
  Future<void> _loadMySiteId() async {
    try {
      final info = await ApiService.getMyInfo();
      if (info['success'] != true) return;
      final raw = info['siteId'];
      final id = (raw is int) ? raw : int.tryParse(raw?.toString() ?? '');
      if (id != null && id > 0) _mySiteId = id;
    } catch (e) {
      debugPrint('관리자 현장 불러오기 실패: $e');
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scanner.stop();
    } catch (e) {
      debugPrint('QR 스캐너 정지 오류: $e');
    }
  }

  Future<void> _startScanner() async {
    try {
      await _scanner.start();
    } catch (e) {
      debugPrint('QR 스캐너 시작 오류: $e');
    }
  }

  // QR 인식 이벤트 (초당 여러 번 불림 → 걸러냄)
  void _onDetect(BarcodeCapture capture) {
    if (_handling || _failMsg != null) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    // 방금 처리한 QR이면 잠깐 무시
    final now = DateTime.now();
    if (code == _lastCode &&
        now.difference(_lastCodeTime).inMilliseconds < _sameCodeIgnoreMs) {
      return;
    }

    _onQrDetected(code);
  }

  // 인증 실패 표시 (스캐너는 멈춘 상태 유지)
  void _showFail(String msg, {bool blocked = false, String name = ''}) {
    if (!mounted) return;
    setState(() {
      _handling = false;
      _failMsg = msg;
      _failBlocked = blocked;
      _failName = name;
    });
  }

  // QR 인증 (1번만 시도)
  Future<void> _onQrDetected(String code) async {
    if (_handling) return;
    setState(() => _handling = true);

    // 인증 중에는 스캐너 정지 → 같은 QR 반복 인식 차단
    await _stopScanner();

    Map<String, dynamic> res;
    try {
      res = await ApiService.verifyQr(code);
    } catch (e) {
      debugPrint('QR 인증 통신 오류: $e');
      res = {'success': false, 'message': '서버에 연결할 수 없어요'};
    }
    if (!mounted) return;

    // ── QR 무효 (없음/만료/출입 차단/통신 오류) ──
    if (res['success'] != true || res['valid'] != true) {
      final msg = res['message']?.toString();
      final text = (msg == null || msg.isEmpty) ? '유효하지 않은 QR 코드예요' : msg;
      // 출입 차단: 서버(QrService)가 "출입이 제한된 작업자입니다…" 문구 + 이름을 보냄
      final bool blocked = text.contains('출입이 제한');
      _showFail(text, blocked: blocked, name: res['name']?.toString() ?? '');
      return;
    }

    // ── 현장 비교 (앱에서 확인) ──
    final raw = res['siteId'];
    final int workerSiteId = (raw is int)
        ? raw
        : int.tryParse(raw?.toString() ?? '') ?? 0;

    // 노동자가 현장에 소속되지 않음
    if (workerSiteId <= 0) {
      _showFail('현장에 소속되지 않은 노동자예요');
      return;
    }

    // 관리자 현장을 아직 못 불러왔으면 한 번 더 시도
    if (_mySiteId == null) await _loadMySiteId();
    if (!mounted) return;
    if (_mySiteId == null) {
      _showFail('현장 정보를 불러오지 못했어요 · 다시 스캔해주세요');
      return;
    }

    // 다른 현장 노동자
    if (workerSiteId != _mySiteId) {
      _showFail('이 현장 소속 노동자가 아니에요');
      return;
    }

    // ── 인증 성공 (같은 현장) → 감지 화면으로 ──
    final userId = res['userId']?.toString() ?? '';
    final name = res['name']?.toString() ?? '';

    // 카메라 박스를 검은 화면 + "인증 완료"로 덮은 채로 넘어감 (멈춘 QR 장면 안 보이게)
    setState(() => _verified = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateDetectionScreen(
          verifiedUserId: userId,
          verifiedName: name,
          verifiedSiteId: workerSiteId, // = 관리자 현장 (위에서 확인됨)
        ),
      ),
    );

    // 돌아오면: 방금 QR은 잠깐 무시하도록 기록
    _lastCode = code;
    _lastCodeTime = DateTime.now();
    if (mounted) {
      setState(() {
        _verified = false;
        _returning = true; // "다음 사람 준비 중..."
      });
    }

    // 감지 화면이 카메라를 완전히 놓을 때까지 잠깐 기다렸다가 재시작
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _startScanner();
    if (mounted) {
      setState(() {
        _handling = false;
        _verified = false;
        _returning = false;
      });
    }
  }

  // [다시 스캔] 버튼
  Future<void> _retry() async {
    setState(() {
      _failMsg = null;
      _failBlocked = false;
      _failName = '';
    });
    // 실패한 QR이 계속 비치고 있어도 바로 재시도하지 않게 잠깐 무시
    _lastCodeTime = DateTime.now();
    await _startScanner();
  }

  @override
  Widget build(BuildContext context) {
    final String failTitle = _failBlocked
        ? (_failName.isNotEmpty ? '출입 제한 · $_failName' : '출입 제한')
        : 'QR 인증 실패';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Gate 입장 - QR 스캔',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 안내 문구 (전면 카메라: 노동자가 화면 앞에 QR을 갖다 댐)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '내 QR 코드를 화면 앞에 비춰주세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),

            // 실제 QR 스캔 카메라 (전면)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      MobileScanner(controller: _scanner, onDetect: _onDetect),
                      // 스캔 가이드 테두리
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // 검증 중 / 넘어가는 중 오버레이
                      // 불투명 검은 화면으로 카메라를 완전히 가림 (멈춘 장면이 비치지 않게)
                      if (_handling && _failMsg == null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: const Color(0xFF111111),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_verified)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 52,
                                      color: Color(0xFF5FBB46),
                                    )
                                  else
                                    const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _verified
                                        ? '인증 완료 · 카메라 준비 중...'
                                        : _returning
                                        ? '다음 사람 준비 중...'
                                        : '인증 확인 중...',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // 인증 실패 오버레이 (출입 차단이면 잠금 아이콘 + 이름)
                      if (_failMsg != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _failBlocked
                                          ? Icons.lock
                                          : Icons.error_outline,
                                      size: 56,
                                      color: const Color(0xFFE24B4A),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      failTitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _failMsg!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    GestureDetector(
                                      onTap: _retry,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          '다시 스캔',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
