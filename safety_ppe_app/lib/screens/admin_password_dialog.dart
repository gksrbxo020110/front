import 'package:flutter/material.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────
// 관리자 비밀번호 확인 팝업 (Gate 관리자 확인 · Gate 나가기 잠금)
// 지금 로그인한 관리자 계정 비밀번호가 맞으면 true
// ─────────────────────────────────────────────
Future<bool> showAdminPasswordDialog(
  BuildContext context, {
  String title = '관리자 확인',
  String message = '관리자 비밀번호를 입력하세요',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdminPasswordDialog(title: title, message: message),
  );
  return ok == true;
}

class _AdminPasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  const _AdminPasswordDialog({required this.title, required this.message});

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final TextEditingController _pw = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_checking) return;
    final text = _pw.text;
    if (text.isEmpty) {
      setState(() => _error = '비밀번호를 입력하세요');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await ApiService.verifyMyPassword(text);
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _checking = false;
      _error = result == null
          ? '서버에 연결할 수 없어요 · 다시 시도해주세요'
          : '비밀번호가 맞지 않아요';
      _pw.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: true,
            autofocus: true,
            enabled: !_checking,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              hintText: '비밀번호',
              errorText: _error,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _checking ? null : _confirm,
          child: Text(_checking ? '확인 중...' : '확인'),
        ),
      ],
    );
  }
}
