import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://192.168.138.182:8000';

  static Future<Map<String, dynamic>> predictDisease(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      return jsonDecode(responseData);
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getWeather() async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/weather'));
      return jsonDecode(response.body);
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMarket() async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/market'));
      return jsonDecode(response.body);
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getHistory(String phone) async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/history/$phone'));
      return jsonDecode(response.body);
    } catch (e) {
      return {"error": e.toString()};
    }
  }
}