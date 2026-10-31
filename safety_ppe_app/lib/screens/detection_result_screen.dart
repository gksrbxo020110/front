import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // [공유 기능] 사진 받아오기
import 'package:share_plus/share_plus.dart'; // [공유 기능]
import 'api_service.dart';
import 'ppe_rules.dart';

// PPE 체크 항목
class PpeCheck {
  final String name;
  final bool worn;
  const PpeCheck(this.name, this.worn);
}

// 감지 결과 화면 (미착용 이력 / 알림에서 열림)
// 실제 저장은 감지 화면(게이트·Inspection)에서 이미 끝난 상태 → 여기선 보여주기 + 공유만
class DetectionResultScreen extends StatefulWidget {
  final String worker; // 노동자 이름
  final String time; // 감지 시간
  final List<PpeCheck> ppeList; // 보호구 착용 여부
  final String? s3Key; // 캡처 사진 (S3 파일 이름)
  final String detectionMode; // 'GATE' / 'INSPECTION' / '' (모름)
  final String workType; // 작업 종류 (Inspection만)
  final bool showSaveButton; // (구 파라미터, 더 이상 안 씀 - 호환용. 가짜 저장 버튼 삭제됨)

  const DetectionResultScreen({
    super.key,
    this.worker = '작업자',
    this.time = '',
    this.ppeList = const [],
    this.s3Key,
    this.detectionMode = '',
    this.workType = '',
    this.showSaveButton = false,
  });

  // ── 서버 감지 기록(DetectionRecordResponse)으로 결과 화면 만들기 ──
  // record: {recordId, detectedAt, detectionMode, workType, siteId, summary, notWornItems, s3Key}
  static DetectionResultScreen fromRecord(
    Map<String, dynamic> record, {
    required String workerName,
  }) {
    final mode = record['detectionMode']?.toString() ?? '';
    final workType = record['workType']?.toString() ?? '';
    final notWorn =
        (record['notWornItems'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];

    return DetectionResultScreen(
      worker: workerName.isEmpty ? '작업자' : workerName,
      time: _formatTime(record['detectedAt']?.toString() ?? ''),
      ppeList: _buildPpeList(mode, workType, notWorn),
      s3Key: record['s3Key']?.toString(),
      detectionMode: mode,
      workType: workType,
    );
  }

  // 서버 미착용 이름(PpeNames.java) → 우리 체크리스트 이름(ppe_rules displayName)
  // 서버: util/ppename/PpeNames.java 확인 완료
  static const Map<String, String> _serverNameToOurs = {
    '방진 마스크': '방진마스크',
    '방독 마스크': '방독마스크',
    '화학용 장갑': '내화학장갑',
    '용접 장갑': '용접장갑',
    '용접 각반': '용접각반',
    '안면 보호구': '보안경/안면보호대',
    '보안경': '보안경/안면보호대',
    '용접 보호면': '보안면',
    '안전모(끈 미체결)': '안전모',
  };

  // 필수 목록에서 미착용만 ✗, 나머지 ✓
  // 서버 이름은 변환표로 우리 이름에 맞춘 뒤 비교
  // 그래도 안 맞으면 추측하지 않고 서버가 준 미착용 항목만 ✗로 표시
  static List<PpeCheck> _buildPpeList(
    String mode,
    String workType,
    List<String> notWorn,
  ) {
    List<String> required = [];
    try {
      final rulesWorkType = mode == 'GATE' ? '' : workType;
      final base = PpeRules.evaluate(rulesWorkType, <String>{});
      required = base.checklist.map((c) => c.displayName).toList();
    } catch (e) {
      debugPrint('필수 목록 불러오기 실패: $e');
    }

    // 용접은 보안면이 없을 때 방진마스크·보안경/안면보호대가 체크리스트에 들어감
    // (evaluate에 빈 라벨을 넣으면 보안면 없음 → 방진마스크, 보안경/안면보호대 포함됨)

    // 서버 이름 → 우리 이름으로 변환 (중복 제거)
    final notWornOurs = notWorn
        .map((n) => _serverNameToOurs[n] ?? n)
        .toSet()
        .toList();

    final allMatched =
        required.isNotEmpty && notWornOurs.every((n) => required.contains(n));

    if (allMatched) {
      return required
          .map((name) => PpeCheck(name, !notWornOurs.contains(name)))
          .toList();
    }
    // 이름이 안 맞는 경우 → 서버가 준 미착용 항목만 (원래 이름 그대로)
    return notWorn.map((name) => PpeCheck(name, false)).toList();
  }

  // 2026-07-08T09:41:00 → 2026.07.08 09:41
  static String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '${d.year}.$mm.$dd $hh:$mi';
    } catch (e) {
      return raw;
    }
  }

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  String? _viewUrl;
  bool _loadingPhoto = false;

  // [공유 기능] 관리자만 공유 가능 (처음엔 숨김 → 역할 확인 후 표시)
  bool _isAdmin = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadRole(); // [공유 기능]
  }

  // s3Key → 조회 URL 받아오기
  Future<void> _loadPhoto() async {
    final key = widget.s3Key;
    if (key == null || key.isEmpty || key == 'null') return;

    setState(() => _loadingPhoto = true);
    try {
      final url = await ApiService.getS3ViewUrl(key);
      if (!mounted) return;
      setState(() {
        _viewUrl = url;
        _loadingPhoto = false;
      });
    } catch (e) {
      debugPrint('사진 URL 불러오기 실패: $e');
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  // ── [공유 기능] 로그인 역할 확인 (폰에 저장된 값, 서버 안 거침) ──
  Future<void> _loadRole() async {
    try {
      final role = await ApiService.getRole();
      if (!mounted) return;
      setState(() => _isAdmin = role == 'ADMIN');
    } catch (e) {
      debugPrint('역할 확인 실패: $e');
    }
  }

  // ── [공유 기능] 공유할 결과 문구 ──
  String _buildShareText() {
    final notWorn = widget.ppeList
        .where((p) => !p.worn)
        .map((p) => p.name)
        .toList();
    final lines = <String>[
      '[AI 스마트 안전 메이트] 감지 결과',
      _subTitle,
      '결과: $_headerTitle',
      if (widget.ppeList.isNotEmpty)
        notWorn.isEmpty ? '모든 보호구 착용' : '미착용: ${notWorn.join(', ')}',
    ];
    return lines.join('\n');
  }

  // ── [공유 기능] 사진 + 문구를 폰 공유창으로 ──
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final text = _buildShareText();

      // 사진이 있으면 받아오기 (없거나 실패하면 문구만 공유)
      List<XFile>? files;
      List<String>? names;
      final url = _viewUrl;
      if (url != null && url.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            files = [XFile.fromData(res.bodyBytes, mimeType: 'image/jpeg')];
            names = ['ppe_result.jpg'];
          }
        } catch (e) {
          debugPrint('공유용 사진 받기 실패: $e');
        }
      }

      await SharePlus.instance.share(
        ShareParams(text: text, files: files, fileNameOverrides: names),
      );
    } catch (e) {
      debugPrint('공유 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공유에 실패했어요'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // 미착용 항목이 하나도 없으면 착용 완료 (iOS가 저장한 착용 완료 기록 대응)
  // 체크리스트가 비어 있으면(정보 없음) 착용 완료로 보지 않음
  bool get _allWorn =>
      widget.ppeList.isNotEmpty && widget.ppeList.every((p) => p.worn);

  // 헤더 문구
  String get _headerTitle {
    final bool isGate = widget.detectionMode == 'GATE';
    if (widget.ppeList.isEmpty) return '감지 결과 정보 없음';
    if (_allWorn) {
      return isGate ? '착용 완료 · 입장 가능' : '착용 완료 · 작업 가능';
    }
    return isGate ? '미착용 감지 · 입장 불가' : '미착용 감지 · 작업 불가';
  }

  // 헤더 색 (착용 완료 = 초록, 미착용 = 빨강, 정보 없음 = 회색)
  Color get _headerColor {
    if (widget.ppeList.isEmpty) return const Color(0xFF6B6B6B);
    return _allWorn ? const Color(0xFF3B7D3F) : const Color(0xFFE24B4A);
  }

  // 부제 (이름 · 모드 · 시간)
  String get _subTitle {
    final parts = <String>[widget.worker];
    if (widget.detectionMode == 'GATE') {
      parts.add('Gate');
    } else if (widget.detectionMode == 'INSPECTION') {
      parts.add(
        widget.workType.isNotEmpty
            ? 'Inspection · ${widget.workType}'
            : 'Inspection',
      );
    }
    if (widget.time.isNotEmpty) parts.add(widget.time);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 앱바 (X 닫기 + 제목) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '감지 결과',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    // ── 결과 헤더 (착용 완료 = 초록 / 미착용 = 빨강) ──
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _headerTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _headerColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 캡처 사진 ──
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildPhoto(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 체크리스트 ──
                    ...widget.ppeList.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  p.worn ? Icons.check : Icons.close,
                                  size: 16,
                                  color: p.worn
                                      ? const Color(0xFF5FBB46)
                                      : const Color(0xFFE24B4A),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: p.worn
                                        ? const Color(0xFF5FBB46)
                                        : const Color(0xFFE24B4A),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  p.worn ? '착용' : '미착용',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B6B6B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── 하단: [공유 기능] 관리자만 표시 ──
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: GestureDetector(
                  onTap: _sharing ? null : _share,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.share,
                          size: 16,
                          color: Color(0xFF6B6B6B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sharing ? '공유 준비 중...' : '공유하기',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 사진 영역
  Widget _buildPhoto() {
    if (_loadingPhoto) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_viewUrl == null || _viewUrl!.isEmpty) {
      return _noPhoto();
    }
    return Image.network(
      _viewUrl!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stack) => _noPhoto(),
    );
  }

  Widget _noPhoto() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, size: 80, color: Color(0xFF3A3A3A)),
          SizedBox(height: 8),
          Text(
            '사진 없음',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
        ],
      ),
    );
  }
}
