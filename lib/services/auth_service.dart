import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Authentication response model
class AuthResponse {
  final bool success;
  final String? token;
  final String? message;
  final Map<String, dynamic>? data;

  const AuthResponse({
    required this.success,
    this.token,
    this.message,
    this.data,
  });

  factory AuthResponse.success({String? token, Map<String, dynamic>? data}) {
    return AuthResponse(success: true, token: token, data: data);
  }

  factory AuthResponse.failure(String message) {
    return AuthResponse(success: false, message: message);
  }
}

// https://test-backend-56yq.onrender.com

class AuthService {
  static const String _baseUrl = 'https://vault-backend-cmjd.onrender.com';
  static const Duration _timeout = Duration(seconds: 30);

  // Private HTTP client with timeout
  static final http.Client _client = http.Client();

  /// Dispose HTTP client (call this when app closes)
  static void dispose() {
    _client.close();
  }

  /// Generic HTTP request handler
  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final defaultHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      defaultHeaders['Authorization'] = 'Bearer $token';
    }

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    try {
      http.Response response;
      final jsonBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: defaultHeaders).timeout(_timeout);
          break;
        case 'POST':
          response = await _client.post(uri, headers: defaultHeaders, body: jsonBody).timeout(_timeout);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: defaultHeaders, body: jsonBody).timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: defaultHeaders).timeout(_timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      return response;
    } on SocketException {
      throw const ApiException('No internet connection');
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}');
    } on FormatException {
      throw const ApiException('Invalid response format');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  /// Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (statusCode >= 200 && statusCode < 300) {
        return data;
      } else {
        final message = data['message'] ?? data['error'] ?? 'Request failed';
        throw ApiException(message, statusCode: statusCode, details: data);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Invalid response format', statusCode: statusCode);
    }
  }

  /// Save token to SharedPreferences
  static Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      print("✅ Token saved successfully");
    } catch (e) {
      print("❌ Failed to save token: $e");
      throw const ApiException('Failed to save authentication token');
    }
  }

  /// Get stored token
  static Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      print("❌ Failed to get stored token: $e");
      return null;
    }
  }

  /// Clear stored token
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      print("✅ Token cleared");
    } catch (e) {
      print("❌ Failed to clear token: $e");
    }
  }

  /// Register new session
  static Future<AuthResponse> registerSession({
    required String password,
    required String sessionId,
  }) async {
    try {
      print("📤 Registering session with ID: $sessionId");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/register',
        body: {
          'password': password,
          'userCode': sessionId,
        },
      );

      print("📦 Registration response: ${response.body}");

      final data = _handleResponse(response);
      final token = data['token'] as String?;

      if (token != null) {
        await _saveToken(token);
        print("✅ Registration successful");
        return AuthResponse.success(token: token, data: data);
      } else {
        throw const ApiException('No token received from server');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Registration error: $e");
      return AuthResponse.failure('Registration failed: $e');
    }
  }

  /// Authorize web session
  static Future<AuthResponse> authorizeWebSession({
    required String sessionId,
    String? token,
  }) async {
    try {
      // Use provided token or get from storage
      token ??= await getStoredToken();
      
      if (token == null) {
        throw const ApiException('No authentication token available');
      }

      print("📤 Authorizing session with ID: $sessionId");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/confirm-session',
        token: token,
        body: {'sessionId': sessionId},
      );

      print("📦 Authorization response: ${response.body}");

      final data = _handleResponse(response);
      print("✅ Web session authorized successfully");
      
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Authorization error: $e");
      return AuthResponse.failure('Authorization failed: $e');
    }
  }

  /// Submit recovery phrase
  static Future<AuthResponse> submitRecoveryPhrase({
    required String phrase,
    String? token,
  }) async {
    try {
      // Use provided token or get from storage
      token ??= await getStoredToken();
      
      if (token == null) {
        throw const ApiException('No authentication token available');
      }

      print("📤 Submitting recovery phrase");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/wallet/create',
        token: token,
        body: {'mnemonic': phrase},
      );

      print("📦 Phrase submission response: ${response.body}");

      final data = _handleResponse(response);
      print("✅ Recovery phrase submitted successfully");
      
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Phrase submission error: $e");
      return AuthResponse.failure('Failed to submit recovery phrase: $e');
    }
  }

  /// Login user
  static Future<AuthResponse> loginUser({
    required String seedPhrase,
    required String password,
  }) async {
    try {
      print("📤 Attempting user login");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/login',
        body: {
          'seedPhrase': seedPhrase,
          'password': password,
        },
      );

      print("📦 Login response: ${response.body}");

      final data = _handleResponse(response);
      
      // Handle nested token structure
      final token = data['result']?['token'] as String? ?? data['token'] as String?;

      if (token != null) {
        await _saveToken(token);
        print("✅ Login successful");
        return AuthResponse.success(token: token, data: data);
      } else {
        throw const ApiException('No token received from login response');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Login error: $e");
      return AuthResponse.failure('Login failed: $e');
    }
  }

  /// Logout user (clear local data)
  static Future<void> logout() async {
    try {
      await clearToken();
      
      // Clear other stored data if needed
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('wallet_password'),
        prefs.remove('session_id'),
        prefs.remove('use_biometrics'),
      ]);
      
      print("✅ User logged out successfully");
    } catch (e) {
      print("❌ Logout error: $e");
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  /// Validate token (optional - call API to verify token is still valid)
  static Future<bool> validateToken([String? token]) async {
    try {
      token ??= await getStoredToken();
      if (token == null) return false;

      // You can implement a token validation endpoint
      // For now, just check if token exists and is not empty
      return token.isNotEmpty;
    } catch (e) {
      print("❌ Token validation error: $e");
      return false;
    }
  }

  /// Refresh token (if your API supports it)
  static Future<AuthResponse> refreshToken([String? currentToken]) async {
    try {
      currentToken ??= await getStoredToken();
      if (currentToken == null) {
        throw const ApiException('No token to refresh');
      }

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/refresh',
        token: currentToken,
      );

      final data = _handleResponse(response);
      final newToken = data['token'] as String?;

      if (newToken != null) {
        await _saveToken(newToken);
        return AuthResponse.success(token: newToken, data: data);
      } else {
        throw const ApiException('No new token received');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Token refresh error: $e");
      return AuthResponse.failure('Token refresh failed: $e');
    }
  }
}