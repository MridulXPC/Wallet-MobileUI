import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:3000';

static Future<bool> registerSession({
  required String password,
  required String sessionId,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password, 'userCode': sessionId}),
    );

    print("📦 Raw response: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      // ✅ Save token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', data['token']);

      print("✅ Token saved: ${data['token']}");
      return true;
    } else {
      print("❌ Registration failed: ${response.statusCode}");
      print("❗ Response body: ${response.body}");
      return false;
    }
  } catch (e) {
    print("🚨 Error registering session: $e");
    return false;
  }
}



  static Future<bool> authorizeWebSession({
    required String sessionId,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/confirm-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sessionId': sessionId}),
      );

      if (response.statusCode == 200) {
        print("✅ Web session authorized");
        return true;
      } else {
        print("❌ Authorization failed: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("🚨 Error authorizing session: $e");
      return false;
    }
  }

  static Future<bool> submitRecoveryPhrase({
  required String phrase,
  required String token,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/wallet/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'mnemonic': phrase}),
    );

    print("📦 Phrase submission response: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Secret phrase submitted successfully");
      return true;
    } else {
      print("❌ Failed to submit phrase: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print("🚨 Error submitting phrase: $e");
    return false;
  }
}

static Future<bool> loginUser({
  required String seedPhrase,
  required String password,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'seedPhrase': seedPhrase,
        'password': password,
      }),
    );

    print("📥 Login response: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final token = data['result']['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);

      print("✅ Login successful, token saved: $token");
      return true;
    } else {
      print("❌ Login failed: ${response.statusCode}");
      print("❗ Response body: ${response.body}");
      return false;
    }
  } catch (e) {
    print("🚨 Error during login: $e");
    return false;
  }
}

}
