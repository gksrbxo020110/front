import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _newPwConfirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _newPwConfirmController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPwController.text.trim();
    final newPw = _newPwController.text.trim();
    final newPwConfirm = _newPwConfirmController.text.trim();

    if (currentPw.isEmpty || newPw.isEmpty) {
      _showMessage('비밀번호를 모두 입력하세요');
      return;
    }
    if (newPw != newPwConfirm) {
      _showMessage('새 비밀번호가 일치하지 않습니다');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.changePassword(
        currentPassword: currentPw,
        newPassword: newPw,
      );
      if (!mounted) return;
      _showMessage('비밀번호가 변경되었습니다', color: AppColors.safe);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage('비밀번호 변경에 실패했습니다. 현재 비밀번호를 확인하세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '비밀번호 변경',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              TextField(
                controller: _currentPwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '현재 비밀번호'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPwController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPwConfirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호 확인'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('변경 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
