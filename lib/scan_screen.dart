import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'main.dart';

class ScanScreen extends StatefulWidget {
  final String userId;
  const ScanScreen({super.key, required this.userId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _fileName = 'leaf.jpg';
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _fileName = file.name.isEmpty ? 'leaf.jpg' : file.name;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not open image: $e');
    }
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$API_URL/predict'))
        ..fields['user_id'] = widget.userId
        ..files.add(http.MultipartFile.fromBytes('file', _imageBytes!,
            filename: _fileName));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        setState(() => _result = jsonDecode(res.body) as Map<String, dynamic>);
      } else {
        setState(() => _error = 'Server error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black54))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Scan Crop'),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGreen),
              ),
              child: _imageBytes == null
                  ? const Center(
                      child: Text('Select a leaf photo',
                          style: TextStyle(color: Colors.grey)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (_imageBytes == null || _isLoading) ? null : _analyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('ANALYZE',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 15),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_result!['disease']}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kGreen)),
                    const Divider(),
                    _row('Crop', '${_result!['crop']}'),
                    _row('Confidence', '${_result!['confidence']}%'),
                    _row('Severity', '${_result!['severity']}'),
                    _row('Medicine', '${_result!['medicine']}'),
                    _row('Dosage', '${_result!['dosage']}'),
                    _row('Frequency', '${_result!['frequency']}'),
                    _row('Tip', '${_result!['tip']}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}