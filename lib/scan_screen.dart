import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  dynamic _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _result = null;
      });
    }
  }

  Future<void> _predict() async {
    if (_selectedImage == null) return;
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8000/predict'),
      );

      final bytes = await _selectedImage.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.jpg',
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final result = jsonDecode(responseData);

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = {"error": e.toString()};
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'None': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Scan Crop 🌿'),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // IMAGE PREVIEW
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF2E7D32), width: 2),
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.green.withOpacity(0.05),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          _selectedImage.path,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.image,
                            size: 60,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 60, color: Color(0xFF2E7D32)),
                          SizedBox(height: 10),
                          Text('Tap to select image',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 20),

            // BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),

            // DETECT BUTTON
            if (_selectedImage != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _predict,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('🔍 Detect Disease',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ),

            SizedBox(height: 20),

            // RESULT CARD
            if (_result != null && !_result!.containsKey('error'))
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: _getSeverityColor(
                        _result!['severity'] ?? 'None'),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text('🌿 Detection Result',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32))),
                    ),
                    Divider(),
                    SizedBox(height: 10),
                    _resultRow('🦠 Disease',
                        _result!['disease'] ?? ''),
                    _resultRow('📊 Confidence',
                        _result!['confidence'] ?? ''),
                    _resultRow(
                        '⚠️ Severity', _result!['severity'] ?? ''),
                    Divider(),
                    _resultRow(
                        '💊 Medicine', _result!['medicine'] ?? ''),
                    _resultRow('💧 Dosage', _result!['dosage'] ?? ''),
                    _resultRow(
                        '📅 Frequency', _result!['frequency'] ?? ''),
                    Divider(),
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(_result!['tip'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ERROR
            if (_result != null && _result!.containsKey('error'))
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '❌ Error: ${_result!['error']}\nMake sure backend is running!',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}