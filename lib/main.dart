import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'scan_screen.dart';
import 'user_profile_screen.dart';

// Chrome/web: localhost | Android emulator: http://10.0.2.2:8000
// Real phone: http://<your-PC-IP>:8000 (same Wi-Fi)
const String API_URL = 'http://localhost:8000';

const Color kGreen = Color(0xFF2E7D32);

void main() {
  runApp(const CropGuardApp());
}

class CropGuardApp extends StatelessWidget {
  const CropGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crop Guard',
      theme: ThemeData(
        primaryColor: kGreen,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
      ),
      home: const LoginScreen(),
    );
  }
}

// ---------------------------------------------------------------- LOGIN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a 10-digit number');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http
          .post(Uri.parse('$API_URL/register'), body: {'phone': phone})
          .timeout(const Duration(seconds: 15));
      debugPrint('register -> ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              phone: phone,
              userId: data['user_id'].toString(),
              existingName: (data['name'] ?? '').toString(),
            ),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Colors.white24, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.grass, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  const Text('Crop Guard',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text('Smart Farming Assistant',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome Farmer!',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kGreen)),
                  const SizedBox(height: 5),
                  const Text('Enter phone number to continue',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 25),
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 15),
                  ],
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixText: '+91  ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text('CONTINUE',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- HOME (tabs)
class HomeScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const HomeScreen({super.key, required this.userId, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  Widget _page() {
    switch (_index) {
      case 1:
        return ScanScreen(userId: widget.userId);
      case 2:
        return const WeatherScreen();
      case 3:
        return const MarketScreen();
      case 4:
        return HistoryScreen(userId: widget.userId);
      default:
        return HomePage(userName: widget.userName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: kGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.wb_sunny), label: 'Weather'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Market'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome!',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wb_sunny, color: Colors.yellow, size: 40),
                        SizedBox(width: 15),
                        Text('28°C  Sunny',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Use the Scan tab to detect crop diseases from a leaf photo.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- WEATHER
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        title: const Text('Weather'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny, size: 100, color: Colors.yellow),
            SizedBox(height: 20),
            Text('28°C',
                style: TextStyle(
                    fontSize: 60,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            Text('Sunny',
                style: TextStyle(fontSize: 20, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- MARKET
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  Widget _card(String name, String price, String change, String icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 35)),
          const SizedBox(width: 15),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kGreen)),
              Text(change,
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Market Price'),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _card('Tomato', '₹25/kg', '+5%', '🍅'),
          _card('Corn', '₹18/kg', '+3%', '🌽'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- HISTORY
class HistoryScreen extends StatefulWidget {
  final String userId;
  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _scans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$API_URL/history?user_id=${widget.userId}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _scans = (data['scans'] ?? []) as List<dynamic>;
      } else {
        _error = 'Server error ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Connection error: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_scans.isEmpty) {
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('No scans yet!',
                style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _scans.length,
        itemBuilder: (_, i) {
          final s = _scans[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.eco, color: kGreen),
              title: Text('${s['crop']} - ${s['disease']}'),
              subtitle: Text(
                  'Severity: ${s['severity']}   Confidence: ${s['confidence']}%\n${s['created_at'] ?? ''}'),
              isThreeLine: true,
            ),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}