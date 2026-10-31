import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'ppe_detector.dart';
import 'ppe_labels.dart';

class DetectionTestScreen extends StatefulWidget {
  const DetectionTestScreen({super.key});

  @override
  State<DetectionTestScreen> createState() => _DetectionTestScreenState();
}

class _DetectionTestScreenState extends State<DetectionTestScreen> {
  final PpeDetector _detector = PpeDetector();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  List<Detection> _results = [];
  bool _loading = false;
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _detector.loadModel();
    setState(() => _modelReady = true);
  }

  Future<void> _pickAndDetect() async {
    // 카메라로 사진 찍기
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _loading = true;
      _results = [];
    });

    // 이미지 읽어서 감지
    final bytes = await picked.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      final results = await _detector.detect(image);
      setState(() {
        _results = results;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 앱바
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PPE 감지 테스트',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // 상태 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: const Color(0xFFF3F3F3),
              child: Text(
                !_modelReady
                    ? '모델 불러오는 중...'
                    : _loading
                    ? '감지 중...'
                    : _results.isEmpty
                    ? (_imageFile == null ? '사진을 촬영하세요' : '감지된 항목 없음')
                    : '${_results.length}개 감지됨',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 찍은 사진
            Expanded(
              child: _imageFile == null
                  ? const Center(
                      child: Text(
                        '아래 버튼으로 사진을 촬영하세요',
                        style: TextStyle(color: Color(0xFF9A9A9A)),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.contain),
                      ),
                    ),
            ),

            // 감지 결과 목록
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: _results.map((d) {
                      final ko = ppeLabelsKo[d.label] ?? d.label;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$ko (${d.label})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(d.confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // 촬영 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _modelReady && !_loading ? _pickAndDetect : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _modelReady && !_loading
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '촬영 & 감지',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
}
