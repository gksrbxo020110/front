import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'inspection_worktype_screen.dart'; // WorkTypeGear, gearKoreanNames

// 모델 클래스 → 서버 ppe_id (모델 클래스 번호와 동일, 조장 확인)
const Map<String, int> _ppeIdMap = {
  'chemical_gloves': 0,
  'dust_mask': 1,
  'face_shield': 2,
  'gaiters': 3,
  'gas_mask': 4,
  'helmet': 5,
  'helmet_nostrap': 6,
  'protective_suit': 7,
  'safety_glasses': 8,
  'safety_gloves': 9,
  'safety_harness': 10,
  'safety_hook': 11,
  'safety_shoes': 12,
  'welding_gaiters': 13,
  'welding_gloves': 14,
  'welding_shield': 15,
};

class InspectionResultScreen extends StatefulWidget {
  final WorkTypeGear workType;
  final String targetUserId;
  final String workerName;
  final Set<String> detectedLabels;
  final Map<String, double> confidence;
  final List<int>? capturedImage;

  const InspectionResultScreen({
    super.key,
    required this.workType,
    required this.targetUserId,
    required this.workerName,
    required this.detectedLabels,
    required this.confidence,
    required this.capturedImage,
  });

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  bool _saving = false;
  bool _isAdmin = false; // 관리자만 공유 버튼 표시

  List<List<String>> get requiredGroups => widget.workType.requiredGroups;
  bool get isWelding => widget.workType.isWelding;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  // 로그인 때 저장된 역할로 관리자 여부 판단 (서버 요청 없음)
  Future<void> _checkRole() async {
    final role = await TokenStorage.getRole();
    if (!mounted) return;
    setState(() => _isAdmin = role == 'ADMIN');
  }

  bool _groupOk(List<String> group) =>
      group.any((g) => widget.detectedLabels.contains(g));

  bool get _allEquipped {
    final baseOk = requiredGroups.every(_groupOk);
    if (!isWelding) return baseOk;
    if (!baseOk) return false;
    final hasShield = widget.detectedLabels.contains('welding_shield');
    if (hasShield) return true;
    final hasMask = widget.detectedLabels.contains('dust_mask');
    final hasEye =
        widget.detectedLabels.contains('safety_glasses') ||
        widget.detectedLabels.contains('face_shield');
    return hasMask && hasEye;
  }

  String get _timeText {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}.${two(now.month)}.${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }

  // 미착용 항목 목록 (한글)
  List<String> get _notWornItems {
    final items = <String>[];
    for (final group in requiredGroups) {
      if (!_groupOk(group)) {
        items.add(group.map((g) => gearKoreanNames[g] ?? g).join('/'));
      }
    }
    if (isWelding) {
      final hasShield = widget.detectedLabels.contains('welding_shield');
      if (!hasShield) {
        final hasMask = widget.detectedLabels.contains('dust_mask');
        final hasEye =
            widget.detectedLabels.contains('safety_glasses') ||
            widget.detectedLabels.contains('face_shield');
        if (!hasMask) items.add('방진마스크');
        if (!hasEye) items.add('보안경/안면보호대');
      }
    }
    return items;
  }

  // 공유하기 (이미지 + 문구)
  Future<void> _share() async {
    final notWorn = _notWornItems;
    final resultText = _allEquipped ? '착용 완료 · 작업 가능' : '미착용 감지 · 작업 불가';
    final notWornText = notWorn.isEmpty ? '없음' : notWorn.join(', ');

    final text =
        '[AI 스마트 안전 메이트] 감지 결과\n'
        '${widget.workerName} · Inspection · ${widget.workType.name} · $_timeText\n'
        '결과: $resultText\n'
        '미착용: $notWornText';

    try {
      if (widget.capturedImage != null) {
        // 이미지를 임시 파일로 저장해서 첨부
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/detection_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(widget.capturedImage!);
        await Share.shareXFiles([XFile(file.path)], text: text);
      } else {
        // 이미지 없으면 문구만
        await Share.share(text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? s3Key;
      if (widget.capturedImage != null) {
        final urlInfo = await ApiService.getS3UploadUrl();
        s3Key = urlInfo['s3Key'];
        await ApiService.uploadImageToS3(
          uploadUrl: urlInfo['uploadUrl']!,
          imageBytes: widget.capturedImage!,
        );
      }

      int? siteId;
      try {
        final myInfo = await ApiService.getMyInfo();
        siteId = myInfo['siteId'] as int?;
      } catch (_) {}

      final items = widget.workType.allGear.map((gear) {
        final worn = widget.detectedLabels.contains(gear);
        return {
          'ppeId': _ppeIdMap[gear],
          'worn': worn,
          'confidence': widget.confidence[gear] ?? 0.0,
        };
      }).toList();

      final inspectorId = await TokenStorage.getUserId();
      final clientUuid =
          'inspection_${DateTime.now().millisecondsSinceEpoch}_${widget.targetUserId}';

      await ApiService.saveDetection(
        clientUuid: clientUuid,
        targetUserId: widget.targetUserId,
        inspectorUserId: inspectorId,
        siteId: siteId,
        detectionMode: 'INSPECTION',
        workType: widget.workType.name,
        s3Key: s3Key,
        items: items,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('점검 결과가 저장되었습니다'),
          backgroundColor: AppColors.safe,
          duration: Duration(seconds: 1),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '감지 결과',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      _allEquipped ? '착용 완료 · 작업 가능' : '미착용 감지 · 작업 불가',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _allEquipped ? AppColors.safe : AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.workerName} · ${widget.workType.name} · $_timeText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.capturedImage != null
                          ? Image.memory(
                              Uint8List.fromList(widget.capturedImage!),
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: Colors.white24,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    ...requiredGroups.map((group) {
                      final label = group
                          .map((g) => gearKoreanNames[g] ?? g)
                          .join('/');
                      return _resultItem(label, _groupOk(group));
                    }),
                    if (isWelding) ..._weldingResultItems(),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('저장'),
                  ),
                  // 공유하기 — 관리자만
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('공유하기'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _weldingResultItems() {
    final hasShield = widget.detectedLabels.contains('welding_shield');
    if (hasShield) {
      return [_resultItem('보안면', true)];
    } else {
      final hasMask = widget.detectedLabels.contains('dust_mask');
      final hasEye =
          widget.detectedLabels.contains('safety_glasses') ||
          widget.detectedLabels.contains('face_shield');
      return [
        _resultItem('보안면', false),
        _resultItem('방진마스크', hasMask),
        _resultItem('보안경/안면보호대', hasEye),
      ];
    }
  }

  Widget _resultItem(String label, bool on) {
    final color = on ? AppColors.safe : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            '${on ? "V" : "X"} $label',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            on ? '착용' : '미착용',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}