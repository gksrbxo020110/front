import 'dart:convert';
import 'package:flutter/material.dart';
import 'qr_generate_screen.dart';
import 'qr_renew_screen.dart';
import 'api_service.dart';

class WorkerQrScreen extends StatefulWidget {
  final bool isTab;
  const WorkerQrScreen({super.key, this.isTab = false});

  @override
  State<WorkerQrScreen> createState() => _WorkerQrScreenState();
}

class _WorkerQrScreenState extends State<WorkerQrScreen> {
  bool loading = true;
  bool hasQr = false;
  String qrImageBase64 = '';
  String expireAt = '';
  String expireAtRaw = ''; // 원본 만료일 (갱신 화면에 넘길 용도)
  String name = '';
  String siteName = '';
  bool hasSite = true; // 소속 현장 있는지 (없으면 QR 사용 불가)
  // ※ 레드 등급은 앱에서 막지 않음: 출입 차단은 게이트 QR 검증에서 서버가 막고,
  //   관리자가 해제하면 바로 입장 가능 (노동자 응답엔 차단 여부 값이 없어서)

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 내 정보 + 내 QR 조회
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      // 내 정보 (이름·현장)
      final info = await ApiService.getMyInfo();
      if (info['success'] == true) {
        name = info['name'] ?? '';
        siteName = info['siteName'] ?? '';
        hasSite = info['siteId'] != null;
      }
      // 현장 없음 → QR 조회 안 함 (화면에서 안내만)
      if (!hasSite) {
        setState(() => hasQr = false);
        return;
      }
      // 내 QR 조회
      final qr = await ApiService.getMyQr();
      if (qr['success'] == true && qr['qrImageBase64'] != null) {
        setState(() {
          hasQr = true;
          qrImageBase64 = qr['qrImageBase64'] ?? '';
          expireAtRaw = qr['expireAt'] ?? '';
          expireAt = _formatDate(qr['expireAt'] ?? '');
        });
      } else {
        setState(() => hasQr = false);
      }
    } catch (e) {
      setState(() => hasQr = false);
    } finally {
      setState(() => loading = false);
    }
  }

  // 날짜 포맷 (2026-07-08T00:00:00 → 2026.07.08)
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return raw;
    }
  }

  // QR 생성 (없을 때) → 유효기간 선택(생성 화면) → 발급
  Future<void> _generateQr() async {
    final validDays = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const QrGenerateScreen()),
    );
    if (validDays == null) return; // 취소
    await _issue(validDays);
  }

  // QR 갱신 (있을 때) → 갱신 화면(빨간 경고, 현재 만료일 표시) → 재발급
  Future<void> _renewQr() async {
    final validDays = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => QrRenewScreen(currentExpireAt: expireAtRaw),
      ),
    );
    if (validDays == null) return; // 취소
    await _issue(validDays);
  }

  // 실제 발급 요청 (생성·갱신 공용)
  Future<void> _issue(int validDays) async {
    setState(() => loading = true);
    try {
      // 발급 직전 한 번 더 확인 (그사이 현장 탈퇴됐을 수 있음)
      final info = await ApiService.getMyInfo();
      final bool siteOk = info['success'] == true && info['siteId'] != null;
      if (!siteOk) {
        _snack('소속 현장이 없어 QR을 발급할 수 없어요');
        await _load();
        return;
      }

      final result = await ApiService.issueQr(validDays: validDays);
      if (result['success'] == true) {
        _snack('QR 코드가 발급되었습니다');
        await _load(); // 다시 조회
      } else {
        _snack(
          ApiService.errorText(
            result['body'],
            fallback: 'QR 발급에 실패했어요 · 다시 시도해주세요',
          ),
        );
        setState(() => loading = false);
      }
    } catch (e) {
      _snack(ApiService.connectionErrorText);
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (!widget.isTab)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 24),
                      ),
                    ),
                  const Text(
                    '내 QR 코드',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                name.isEmpty ? '이름 없음' : name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                siteName.isEmpty ? '소속 현장 없음' : siteName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
              ),
              const SizedBox(height: 24),

              if (loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6FA8F5)),
                  ),
                )
              else if (!hasSite)
                ..._qrBlocked(
                  icon: Icons.location_off_outlined,
                  color: const Color(0xFF9A9A9A),
                  title: '소속 현장이 없어요',
                  desc: '현장에 등록해야 QR 코드를 만들 수 있어요\n현장 관리에서 현장 코드로 등록하세요',
                )
              else if (hasQr)
                ..._qrExists()
              else
                ..._qrEmpty(),

              if (!loading) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _qrExists() {
    return [
      Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: qrImageBase64.isNotEmpty
            ? Image.memory(base64Decode(qrImageBase64), fit: BoxFit.contain)
            : const Icon(Icons.qr_code_2, size: 100, color: Color(0xFFCCCCCC)),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6FA8F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '유효기간 : $expireAt 까지',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '스캔이 잘 되도록 화면 밝기를 높여주세요',
        style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
      ),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _renewQr, // 갱신 화면(빨간 경고)으로
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'QR 갱신',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
          ),
        ),
      ),
    ];
  }

  // QR 사용 불가 (현장 없음) — 생성·갱신 버튼 없음
  List<Widget> _qrBlocked({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return [
      Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 80, color: color),
      ),
      const SizedBox(height: 20),
      Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color == const Color(0xFFE24B4A) ? color : null,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        desc,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
      ),
      const SizedBox(height: 24),
      // 현장 등록 후 다시 확인 (탭 화면은 자동으로 안 바뀌어서)
      GestureDetector(
        onTap: _load,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 16, color: Color(0xFF4A4A4A)),
              SizedBox(width: 4),
              Text(
                '다시 확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4A4A),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _qrEmpty() {
    return [
      Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFF6FA8F5), width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.qr_code_2, size: 100, color: Color(0xFFCCCCCC)),
      ),
      const SizedBox(height: 20),
      const Text(
        '아직 QR 코드가 없어요',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'QR을 생성하면 현장 입장에 사용할 수 있어요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _generateQr, // 생성 화면(파란 안내)으로
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16, color: Color(0xFF4A4A4A)),
              SizedBox(width: 4),
              Text(
                'QR 코드 생성',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4A4A),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
