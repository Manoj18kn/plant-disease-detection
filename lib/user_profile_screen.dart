import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class UserProfileScreen extends StatefulWidget {
  final String phone;
  final String userId;
  final String existingName;
  const UserProfileScreen({
    super.key,
    required this.phone,
    required this.userId,
    this.existingName = '',
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final TextEditingController _nameController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$API_URL/profile'),
        body: {'user_id': widget.userId, 'name': name},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(userId: widget.userId, userName: name),
          ),
        );
      } else {
        setState(() => _error = 'Server error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text('Complete Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const CircleAvatar(
              radius: 55,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.person, size: 60, color: kGreen),
            ),
            const SizedBox(height: 30),
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 15),
            ],
            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Your Name',
                prefixIcon: const Icon(Icons.person, color: kGreen),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: TextEditingController(text: '+91 ${widget.phone}'),
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Phone',
                prefixIcon: const Icon(Icons.phone, color: kGreen),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('Continue',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}