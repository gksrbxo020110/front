import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'qr_renew_screen.dart';
import 'qr_create_screen.dart';

class WorkerQrScreen extends StatefulWidget {
  const WorkerQrScreen({super.key});

  @override
  State<WorkerQrScreen> createState() => _WorkerQrScreenState();
}

class _WorkerQrScreenState extends State<WorkerQrScreen> {
  Map<String, dynamic>? myQr; // 내 QR (없으면 null)
  bool isLoading = true;

  bool _hasSite = false; // 소속 현장 보유 여부
  bool _isRed = false; // 안전등급 레드 여부

  @override
  void initState() {
    super.initState();
    _loadMyQr();
  }

  // 내 QR + 현장 소속 + 안전등급 조회
  Future<void> _loadMyQr() async {
    setState(() => isLoading = true);
    try {
      final qr = await ApiService.getMyQr();

      // 현장 소속 여부
      bool hasSite = false;
      try {
        final site = await ApiService.getMySite();
        hasSite = site != null;
      } catch (_) {}

      // 안전등급 (레드 여부)
      bool isRed = false;
      try {
        final dash = await ApiService.getWorkerDashboard();
        isRed = dash['grade'] == 'RED';
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        myQr = qr;
        _hasSite = hasSite;
        _isRed = isRed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR 조회 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 만료일 문구 만들기 (expireAt → "2026.07.15 까지")
  String _expireText() {
    final expireAt = myQr?['expireAt'];
    if (expireAt == null) return '';
    try {
      final dt = DateTime.parse(expireAt.toString());
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '유효기간: $y.$m.$d 까지';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '내 QR 코드',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const CircularProgressIndicator()
              else if (myQr != null)
                ..._qrExists()
              else
                ..._qrEmpty(),
            ],
          ),
        ),
      ),
    );
  }

  // QR 있을 때
  List<Widget> _qrExists() {
    final base64Str = myQr!['qrImageBase64'] as String?;

    return [
      // 진짜 QR 이미지 (base64 디코딩)
      Container(
        width: 240,
        height: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: (base64Str != null && base64Str.isNotEmpty)
            ? Image.memory(
                base64Decode(base64Str),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              )
            : const Icon(Icons.qr_code_2, size: 160, color: AppColors.primary),
      ),
      const SizedBox(height: 20),
      // 유효기간
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              _expireText(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // 레드 등급 안내 (갱신 불가)
      if (_isRed)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '안전 등급이 레드입니다 · QR 갱신이 제한됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ),
      const Text(
        '스캔이 잘 되도록 화면 밝기를 높여주세요',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            // 현장 없으면 갱신 불가
            if (!_hasSite) {
              _showMessage('소속된 현장이 없습니다 · 먼저 현장에 참여해주세요');
              return;
            }
            // 레드 등급이면 갱신 불가
            if (_isRed) {
              _showMessage('안전 등급이 레드입니다 · QR을 갱신할 수 없습니다');
              return;
            }
            // 갱신 화면에 현재 만료일 넘기고, 갔다 오면 다시 조회
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    QrRenewScreen(expireAt: myQr?['expireAt']?.toString()),
              ),
            );
            await _loadMyQr();
          },
          child: const Text('QR 갱신'),
        ),
      ),
    ];
  }

  // QR 없을 때 (만료/미발급)
  List<Widget> _qrEmpty() {
    return [
      Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.qr_code_2, size: 160, color: Color(0xFFD0D0D0)),
      ),
      const SizedBox(height: 24),
      Text(
        _hasSite ? '아직 QR 코드가 없어요' : '소속된 현장이 없어요',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        _hasSite ? 'QR을 생성하면 현장 입장에 사용할 수 있어요' : '현장 코드를 등록하면 QR을 생성할 수 있어요',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            // 현장 없으면 생성 불가
            if (!_hasSite) {
              _showMessage('소속된 현장이 없습니다 · 먼저 현장에 참여해주세요');
              return;
            }
            // 생성 화면 갔다 오면 다시 조회
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrCreateScreen()),
            );
            await _loadMyQr();
          },
          child: const Text('+ QR 코드 생성'),
        ),
      ),
    ];
  }
}
