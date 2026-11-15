import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class SiteCreateScreen extends StatefulWidget {
  const SiteCreateScreen({super.key});

  @override
  State<SiteCreateScreen> createState() => _SiteCreateScreenState();
}

class _SiteCreateScreenState extends State<SiteCreateScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool isIssued = false; // 코드 발급 완료 여부
  String issuedCode = ''; // 발급된 코드
  bool isLoading = false; // 서버 요청 중 여부

  // 두 항목 다 입력됐는지 (버튼 활성화 조건)
  bool get canIssue =>
      nameController.text.trim().isNotEmpty &&
      addressController.text.trim().isNotEmpty;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // 서버에 현장 생성 요청 → 진짜 현장 코드 발급받음
  Future<void> _issueCode() async {
    setState(() => isLoading = true);

    try {
      final result = await ApiService.createSite(
        siteName: nameController.text.trim(),
        address: addressController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        issuedCode = result['siteCode'] ?? '';
        isIssued = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('현장 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isIssued ? '현장 생성 완료' : '현장 등록/생성',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: isIssued ? _issuedView() : _formView(),
        ),
      ),
    );
  }

  // 입력 폼 화면
  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '현장 정보를 입력하면 코드가 발급됩니다.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        const Text(
          '현장명',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          onChanged: (_) => setState(() {}), // 입력할 때마다 버튼 상태 갱신
          decoration: const InputDecoration(hintText: '예) 신한 제2공사 현장'),
        ),
        const SizedBox(height: 20),

        const Text(
          '현장 주소',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '예) 경기 의정부시 호암로95'),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          // 둘 다 입력하고, 요청 중이 아닐 때만 활성화
          onPressed: (canIssue && !isLoading) ? _issueCode : null,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('현장 코드 발급'),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '두 항목을 모두 입력해야 발급됩니다',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // 발급 완료 화면
  Widget _issuedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '아래 코드를 노동자에게 전달하세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // 입력했던 현장명·주소
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            nameController.text,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            addressController.text,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        const SizedBox(height: 20),

        // 발급된 코드 (초록 카드)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E6C9), // 연초록
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.safe,
                size: 28,
              ),
              const SizedBox(height: 8),
              const Text(
                '발급된 현장 코드',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                issuedCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('현장 코드가 복사되었습니다'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(
                  Icons.share,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () {
            // 새 현장 정보를 목록 화면으로 넘기며 돌아감
            Navigator.pop(context, {
              'name': nameController.text,
              'workers': '0',
              'code': issuedCode,
            });
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
