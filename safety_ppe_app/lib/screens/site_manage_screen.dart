import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

// ══════════ 1. 현장 관리 (1인 1현장, 서버 연동 + 노동자 목록/해제) ══════════
class SiteManageScreen extends StatefulWidget {
  const SiteManageScreen({super.key});

  @override
  State<SiteManageScreen> createState() => _SiteManageScreenState();
}

class _SiteManageScreenState extends State<SiteManageScreen> {
  bool loading = true;
  bool hasSite = false;
  String siteCode = '';
  String siteName = '';
  String address = '';
  int workerCount = 0;

  // 노동자 목록
  List<Map<String, dynamic>> workers = [];

  @override
  void initState() {
    super.initState();
    _loadMySite();
  }

  Future<void> _loadMySite() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.getMySite();
      if (result['success'] == true && result['siteCode'] != null) {
        final count = await ApiService.getWorkerCount();
        final list = await ApiService.getSiteWorkerList();
        setState(() {
          hasSite = true;
          siteCode = result['siteCode'] ?? '';
          siteName = result['siteName'] ?? '';
          address = result['address'] ?? '';
          workerCount = count;
          workers = list;
        });
      } else {
        setState(() => hasSite = false);
      }
    } catch (e) {
      setState(() => hasSite = false);
    } finally {
      setState(() => loading = false);
    }
  }

  // 현장 삭제 버튼 → 서버 규칙(SiteService.deleteSite)에 맞춰 안내
  // 서버: 소속 노동자가 1명이라도 있으면 삭제 거부, 0명이면 삭제 + 관리자 본인 소속 해제
  void _showDeleteDialog() {
    if (workerCount > 0) {
      _showCannotDeleteDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete,
                  color: Color(0xFFE24B4A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현장을 삭제할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: siteName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '\n현장과 현장 코드가 삭제되며\n'),
                    const TextSpan(
                      text: '되돌릴 수 없습니다.',
                      style: TextStyle(
                        color: Color(0xFFE24B4A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _deleteSite();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '삭제',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 노동자가 남아 있을 때 → 삭제 불가 안내 (서버도 같은 이유로 거부함)
  void _showCannotDeleteDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  color: Color(0xFFE24B4A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현장을 삭제할 수 없어요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: '소속 노동자 '),
                    TextSpan(
                      text: '$workerCount명',
                      style: const TextStyle(
                        color: Color(0xFFE24B4A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '이 남아 있습니다.\n노동자를 모두 소속 해제한 후\n삭제할 수 있습니다.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '확인',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSite() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.deleteSite();
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현장이 삭제되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          hasSite = false;
          siteCode = '';
          siteName = '';
          address = '';
          workerCount = 0;
          workers = [];
        });
        await _loadMySite();
      } else {
        // 실패 이유 구분 (서버 메시지: SiteService.deleteSite)
        final body = result['body']?.toString() ?? '';
        String msg;
        if (body.contains('노동자')) {
          msg = '소속 노동자가 남아 있어 삭제할 수 없습니다';
        } else if (body.contains('다른 관리자')) {
          msg = '다른 관리자가 있어 삭제할 수 없습니다';
        } else {
          msg = '현장 삭제에 실패했습니다 · 잠시 후 다시 시도해주세요';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
        await _loadMySite(); // 노동자 수 등 최신 상태로 갱신
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버에 연결할 수 없어요'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => loading = false);
    }
  }

  // 노동자 소속 해제 확인 팝업
  void _showRemoveDialog(Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove,
                  color: Color(0xFFE24B4A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '노동자를 소속 해제할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: '${worker['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' 님을 현장에서\n소속 해제합니다.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _removeWorker(worker['userId']);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '소속 해제',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 노동자 소속 해제 (서버)
  Future<void> _removeWorker(String targetUserId) async {
    try {
      final result = await ApiService.removeWorker(targetUserId);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('노동자 소속이 해제되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
        await _loadMySite(); // 목록·노동자 수 갱신
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('해제 실패: ${result['body']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('서버 연결 실패: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  siteName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog();
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: Color(0xFFE24B4A),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '현장 삭제',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE24B4A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, size: 26),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '현장 관리',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '현장을 만들면 코드가 생성됩니다. 노동자가 이 코드로 현장에 등록합니다.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
              ),

              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : hasSite
                    ? ListView(
                        padding: const EdgeInsets.only(top: 16),
                        children: [
                          _siteCard(),
                          const SizedBox(height: 20),
                          _workerSection(),
                        ],
                      )
                    : _emptyState(),
              ),

              if (!loading && !hasSite)
                GestureDetector(
                  onTap: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SiteCreateScreen(),
                      ),
                    );
                    if (created == true) _loadMySite();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '현장 등록/생성',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.home_work_outlined, size: 60, color: Color(0xFF9A9A9A)),
          SizedBox(height: 16),
          Text(
            '등록된 현장이 없습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            '첫 현장을 만들고\n노동자에게 코드를 전달하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9A9A9A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siteName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '노동자 $workerCount명 · 사용중',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showMenu,
                child: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  siteCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: siteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('현장 코드($siteCode)가 복사되었습니다'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.link,
                    size: 18,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 노동자 목록 섹션
  Widget _workerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소속 노동자',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 10),
        if (workers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '아직 등록된 노동자가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
            ),
          )
        else
          ...workers.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0DEF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF7F77DD),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w['name']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${w['nickname']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showRemoveDialog(w),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCEBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '소속 해제',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE24B4A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════ 2. 현장 정보 입력 (서버 연동, 오버플로우 수정) ══════════
class SiteCreateScreen extends StatefulWidget {
  const SiteCreateScreen({super.key});

  @override
  State<SiteCreateScreen> createState() => _SiteCreateScreenState();
}

class _SiteCreateScreenState extends State<SiteCreateScreen> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  bool loading = false;

  bool get isValid =>
      nameController.text.trim().isNotEmpty &&
      addressController.text.trim().isNotEmpty;

  Future<void> _create() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.createSite(
        nameController.text.trim(),
        addressController.text.trim(),
      );
      if (result['success'] == true) {
        if (!mounted) return;
        final done = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SiteCreatedScreen(
              siteName: result['siteName'] ?? nameController.text,
              siteAddress: result['address'] ?? addressController.text,
              siteCode: result['siteCode'] ?? '',
            ),
          ),
        );
        if (done == true && mounted) {
          Navigator.pop(context, true);
        } else {
          setState(() => loading = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('현장 생성 실패: ${result['body']}'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => loading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('서버 연결 실패: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.chevron_left, size: 26),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '현장 등록/생성',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '현장 정보를 입력하면 코드가 발급됩니다.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    const Text(
                      '현장명',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputStyle('예) 신한 제2공사 현장'),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '현장 주소',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputStyle('예) 경기 의정부시 호암로 95'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: (isValid && !loading) ? _create : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: (isValid && !loading)
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loading ? '발급 중...' : '현장 코드 발급',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (isValid && !loading)
                              ? Colors.white
                              : const Color(0xFF9A9A9A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '두 항목을 모두 입력해야 발급됩니다',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
      ),
    );
  }
}

// ══════════ 3. 현장 생성 완료 (서버가 준 코드) ══════════
class SiteCreatedScreen extends StatelessWidget {
  final String siteName;
  final String siteAddress;
  final String siteCode;
  const SiteCreatedScreen({
    super.key,
    required this.siteName,
    required this.siteAddress,
    required this.siteCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, size: 26),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '현장 생성 완료',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '아래 코드를 노동자에게 전달하세요.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
              ),
              const SizedBox(height: 24),
              _infoBox(siteName),
              const SizedBox(height: 12),
              _infoBox(siteAddress),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF5E1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF1D9E75),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '발급된 현장 코드',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      siteCode.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: siteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('현장 코드가 복사되었습니다'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.link,
                        size: 22,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '이 현장에 관리자로 자동 등록되었습니다',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3B6D11)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '확인',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
