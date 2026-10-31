import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'api_service.dart';

// 회원 탈퇴
// 서버 규칙 (UserService.deleteAccount 확인):
//   1) 비밀번호가 맞아야 함
//   2) 현장에 소속되어 있으면(siteId != null) 관리자·노동자 모두 탈퇴 불가
//      → 관리자는 현장 삭제, 노동자는 현장 나가기 후 탈퇴 가능
// 앱은 화면을 열 때 getMyInfo로 소속 여부를 미리 확인해서 안내 + 버튼 막기
class WithdrawScreen extends StatefulWidget {
  final bool isManager; // true=관리자, false=노동자 (안내 문구만 다름)
  const WithdrawScreen({super.key, this.isManager = true});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final pwController = TextEditingController();
  bool agreed = false;
  bool loading = false; // 탈퇴 요청 중

  bool _checking = true; // 현장 소속 확인 중
  bool _inSite = false; // 현장에 소속되어 있음 → 탈퇴 불가
  String _siteName = ''; // 소속 현장 이름 (안내용)

  @override
  void initState() {
    super.initState();
    _checkSite();
  }

  @override
  void dispose() {
    pwController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 현장 소속 여부 확인 (서버 getMyInfo의 siteId)
  // 확인에 실패하면 막지 않음 → 서버가 최종 판단
  Future<void> _checkSite() async {
    bool inSite = false;
    String siteName = '';
    try {
      final info = await ApiService.getMyInfo();
      if (info['success'] == true) {
        final raw = info['siteId'];
        final int id = (raw is int)
            ? raw
            : int.tryParse(raw?.toString() ?? '') ?? 0;
        inSite = id > 0;
        siteName = info['siteName']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('현장 소속 확인 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _inSite = inSite;
      _siteName = siteName;
      _checking = false;
      if (inSite) agreed = false;
    });
  }

  // 탈퇴 버튼을 누를 수 없는 상태
  bool get _disabled => _checking || _inSite || loading;

  // 소속 안내 문구 (서버 메시지와 같은 내용, 역할별로 할 일만 다르게)
  String get _blockedText {
    final site = _siteName.isNotEmpty ? '[$_siteName] ' : '';
    return widget.isManager
        ? '${site}현장에 소속되어 있어 탈퇴할 수 없습니다.\n현장 관리에서 현장을 삭제한 후 탈퇴하세요.'
        : '${site}현장에 소속되어 있어 탈퇴할 수 없습니다.\n현장 관리에서 현장을 나간 후 탈퇴하세요.';
  }

  Future<void> _withdraw() async {
    if (_disabled) return;
    if (pwController.text.isEmpty) {
      _snack('현재 비밀번호를 입력해주세요');
      return;
    }
    if (!agreed) {
      _snack('탈퇴 동의를 확인해주세요');
      return;
    }

    setState(() => loading = true);
    try {
      final result = await ApiService.deleteAccount(pwController.text);
      if (result['success'] == true) {
        await ApiService.clearToken(); // 토큰 삭제 (프론트 담당)
        if (!mounted) return;
        _snack('회원 탈퇴가 완료되었습니다');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      // 실패 이유 구분 (서버 메시지: UserService.deleteAccount)
      final body = result['body']?.toString() ?? '';
      if (body.contains('현장')) {
        // 그 사이 현장에 소속됨 → 안내 상자 띄우고 막기
        if (mounted) {
          setState(() {
            _inSite = true;
            agreed = false;
          });
        }
        _snack('현장에 소속되어 있어 탈퇴할 수 없습니다');
      } else if (body.contains('비밀번호')) {
        _snack('비밀번호를 확인해주세요');
      } else {
        _snack('탈퇴에 실패했습니다 · 잠시 후 다시 시도해주세요');
      }
    } catch (e) {
      _snack('서버에 연결할 수 없어요');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // 앱바
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 24),
                      ),
                    ),
                    const Text(
                      '회원 탈퇴',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 경고 아이콘
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCEBEB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE24B4A),
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '정말 탈퇴하시겠어요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '탈퇴 시 계정과 모든 데이터가 삭제되며\n복구할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9A9A),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 탈퇴 불가 안내 (현장에 소속되어 있을 때 · 관리자/노동자 공통)
                if (_inSite) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      border: Border.all(color: const Color(0xFFE24B4A)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.block,
                          color: Color(0xFFE24B4A),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '탈퇴할 수 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE24B4A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _blockedText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFA32D2D),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 삭제되는 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '삭제되는 정보',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '• 계정 정보 (아이디, 이름)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                          height: 1.8,
                        ),
                      ),
                      Text(
                        widget.isManager ? '• 관리하던 현장 정보' : '• 소속 현장 및 QR 정보',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                          height: 1.8,
                        ),
                      ),
                      const Text(
                        '• 알림 및 설정 정보',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 비밀번호 확인
                const Text(
                  '비밀번호 확인',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pwController,
                  obscureText: true,
                  enabled: !_inSite,
                  decoration: InputDecoration(
                    hintText: '현재 비밀번호를 입력하세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE24B4A),
                        width: 1.3,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 동의 체크박스
                GestureDetector(
                  onTap: _inSite
                      ? null
                      : () => setState(() => agreed = !agreed),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        agreed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 22,
                        color: agreed
                            ? const Color(0xFFE24B4A)
                            : const Color(0xFFB0B0B0),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '위 내용을 확인했으며 탈퇴에 동의합니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 회원 탈퇴 버튼
                GestureDetector(
                  onTap: _disabled ? null : _withdraw,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _disabled
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFFE24B4A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loading
                          ? '처리 중...'
                          : _checking
                          ? '확인 중...'
                          : '회원 탈퇴',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _disabled
                            ? const Color(0xFF9A9A9A)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 취소 버튼
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '취소',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
