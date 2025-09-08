import 'dart:convert';
import 'dart:io';
import 'package:cryptowallet/models/token_model.dart';
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

class AuthService {
  static const String _baseUrl = 'https://vault-backend-cmjd.onrender.com';
  static const Duration _timeout = Duration(seconds: 30);

  // SharedPreferences keys
  static const String _spTokenKey = 'jwt_token';
  static const String _spUserIdKey = 'user_id';
  static const String _spWalletIdKey = 'wallet_id';

  // Private HTTP client with timeout
  static final http.Client _client = http.Client();
  static void dispose() => _client.close();

  /// Generic HTTP request handler (auto-attaches JWT in Authorization header)
  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? token,
    bool requireAuth = true, // default: most endpoints require auth
  }) async {
    // Allow caller to override token, else use stored token
    token ??= await getStoredToken();

    if (requireAuth && (token == null || token.isEmpty)) {
      throw const ApiException('No authentication token available');
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    final defaultHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (headers != null) defaultHeaders.addAll(headers);

    try {
      http.Response response;
      final jsonBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'GET':
          response =
              await _client.get(uri, headers: defaultHeaders).timeout(_timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: defaultHeaders, body: jsonBody)
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: defaultHeaders, body: jsonBody)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: defaultHeaders)
              .timeout(_timeout);
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

  // -------------------- TOKEN STORAGE --------------------
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spTokenKey, token);
  }

  static Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_spTokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spTokenKey);
  }

  // -------------------- AUTH FLOWS --------------------
  /// Register new session (no auth header yet)
  static Future<AuthResponse> registerSession({
    required String password,
    required String sessionId,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/register',
        body: {
          'password': password,
          'userCode': sessionId,
        },
        requireAuth: false, // no JWT for register
      );

      final data = _handleResponse(response);
      final token = data['token'] as String?;
      if (token != null) {
        await _saveToken(token);
        return AuthResponse.success(token: token, data: data);
      } else {
        throw const ApiException('No token received from server');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Registration failed: $e');
    }
  }

  /// Authorize web session (requires auth)
  static Future<AuthResponse> authorizeWebSession({
    required String sessionId,
    String? token,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/confirm-session',
        token: token, // optional override
        body: {'sessionId': sessionId},
        requireAuth: true,
      );

      final data = _handleResponse(response);
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Authorization failed: $e');
    }
  }

  /// Submit recovery phrase (requires auth)
  static Future<AuthResponse> submitRecoveryPhrase({
    required String phrase,
    String? token,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/wallet/create',
        token: token, // optional override
        body: {'mnemonic': phrase},
        requireAuth: true,
      );

      final data = _handleResponse(response);
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Failed to submit recovery phrase: $e');
    }
  }

  /// Login user (no auth header yet)
  static Future<AuthResponse> loginUser({
    required String seedPhrase,
    required String password,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/login',
        body: {
          'seedPhrase': seedPhrase,
          'password': password,
        },
        requireAuth: false, // no JWT for login
      );

      final data = _handleResponse(response);
      final token =
          data['result']?['token'] as String? ?? data['token'] as String?;
      if (token != null) {
        await _saveToken(token);
        return AuthResponse.success(token: token, data: data);
      } else {
        throw const ApiException('No token received from login response');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Login failed: $e');
    }
  }

  /// Logout user (clear local data)
  static Future<void> logout() async {
    try {
      await clearToken();
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('wallet_password'),
        prefs.remove('session_id'),
        prefs.remove('use_biometrics'),
        prefs.remove(_spUserIdKey), // also clear cached userId
        prefs.remove(_spWalletIdKey), // also clear cached walletId
      ]);
    } catch (_) {}
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  /// Validate token (optional - basic check)
  static Future<bool> validateToken([String? token]) async {
    try {
      token ??= await getStoredToken();
      if (token == null) return false;
      return token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Refresh token (if your API supports it)
  static Future<AuthResponse> refreshToken([String? currentToken]) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/auth/refresh',
        token: currentToken, // optional override
        requireAuth: true,
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
      return AuthResponse.failure('Token refresh failed: $e');
    }
  }

  // -------------------- TOKENS (ASSETS) --------------------
  static Future<List<VaultToken>> fetchTokens({String? token}) async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/token/get-tokens',
        token: token, // optional override
        requireAuth: true, // header token mandatory
      );

      final data = _handleResponse(response);
      final List<dynamic> list = (data['data'] as List?) ?? const [];
      final tokens = list
          .whereType<Map<String, dynamic>>()
          .map((e) => VaultToken.fromJson(e))
          .toList();
      return tokens;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch tokens: $e');
    }
  }

  // -------------------- USER ID: /api/auth/me --------------------
  static Future<void> _saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spUserIdKey, userId);
  }

  static Future<String?> getStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_spUserIdKey);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/auth/me -> returns "user" map and caches _id
  static Future<Map<String, dynamic>> fetchMe({String? token}) async {
    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    final res = await _makeRequest(
      method: 'GET',
      endpoint: '/api/auth/me',
      token: token,
      requireAuth: true,
    );
    final data = _handleResponse(res);

    final user = (data['user'] as Map?)?.cast<String, dynamic>();
    if (user == null) {
      throw const ApiException('Malformed response: "user" missing');
    }

    final id = user['_id']?.toString();
    if (id != null && id.isNotEmpty) {
      await _saveUserId(id);
    }

    return user;
  }

  /// Returns cached userId if present; else fetches it from /api/auth/me.
  static Future<String?> getOrFetchUserId() async {
    final cached = await getStoredUserId();
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final user = await fetchMe();
      final id = user['_id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  // -------------------- WALLETS: /api/wallet/get-wallets --------------------
  static Future<void> _saveWalletId(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spWalletIdKey, walletId);
  }

  static Future<String?> getStoredWalletId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_spWalletIdKey);
    } catch (_) {
      return null;
    }
  }

  // Normalize symbol→backend chain for wallet selection
  static String _normalizeChainForWallets(String chain) {
    final u = chain.toUpperCase();
    if (u == 'TRX') return 'TRON';
    return u;
  }

  /// GET /api/wallet/get-wallets (returns list of wallets)
  static Future<List<Map<String, dynamic>>> fetchWallets(
      {String? token}) async {
    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    final res = await _makeRequest(
      method: 'GET',
      endpoint: '/api/wallet/get-wallets',
      token: token,
      requireAuth: true,
    );
    final data = _handleResponse(res);

    final list = (data['wallets'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Pick a wallet. If `chain` provided, prefer a wallet that has that chain.
  /// Otherwise pick the most recently updated wallet.
  static Map<String, dynamic>? _pickWallet(
    List<Map<String, dynamic>> wallets, {
    String? chain,
  }) {
    final want = chain != null ? _normalizeChainForWallets(chain) : null;

    Map<String, dynamic>? best;
    DateTime? bestTime;

    for (final w in wallets) {
      final chains = (w['chains'] as List?) ?? const [];
      final hasWanted = want == null
          ? true
          : chains.any((c) {
              final m = (c as Map).cast<String, dynamic>();
              return (m['chain']?.toString().toUpperCase() ?? '') == want;
            });

      if (!hasWanted) continue;

      DateTime? t;
      final ts = w['updatedAt']?.toString();
      if (ts != null) {
        try {
          t = DateTime.parse(ts);
        } catch (_) {}
      }

      if (best == null ||
          (t != null && (bestTime == null || t.isAfter(bestTime!)))) {
        best = w;
        bestTime = t;
      }
    }

    best ??= wallets.isNotEmpty ? wallets.first : null;
    return best;
  }

  /// Returns cached walletId if present; else fetches wallets and picks one.
  /// If `chain` provided, prefers a wallet that supports that chain.
  static Future<String?> getOrFetchWalletId({String? chain}) async {
    final cached = await getStoredWalletId();
    if (cached != null && cached.isNotEmpty) return cached;

    final wallets = await fetchWallets();
    final picked = _pickWallet(wallets, chain: chain);
    final id = picked?['_id']?.toString();
    if (id != null && id.isNotEmpty) {
      await _saveWalletId(id);
      return id;
    }
    return null;
  }

  /// Convenience: get the address for a given chain from your wallets.
  static Future<String?> getWalletAddressForChain(String chain) async {
    final want = _normalizeChainForWallets(chain);
    final wallets = await fetchWallets();
    for (final w in wallets) {
      final chains = (w['chains'] as List?) ?? const [];
      for (final c in chains) {
        final m = (c as Map).cast<String, dynamic>();
        if ((m['chain']?.toString().toUpperCase() ?? '') == want) {
          return m['address']?.toString();
        }
      }
    }
    return null;
  }

  // -------------------- TRANSACTIONS --------------------
  /// POST /api/transaction/send
  /// Header: Authorization: Bearer <jwt> (mandatory)
  /// Body: userID, walletId, toAddress, amount, chain, priority (optional)
  /// NOTE: If your backend also expects the JWT in the body, keep `"token": token`.
  static Future<AuthResponse> sendTransaction({
    required String userId,
    required String walletId,
    required String toAddress,
    required String amount,
    required String chain,
    String priority = "yes",
    String? token,
  }) async {
    try {
      token ??= await getStoredToken();
      if (token == null) {
        throw const ApiException("No authentication token available");
      }

      // Build request body
      final requestBody = <String, dynamic>{
        "userID": userId,
        "walletId": "1CvqaKTECKr6fhYcpDgJRPpBrrU3grL6vz",
        "toAddress": toAddress,
        "amount": amount,
        "priority": priority,
        "chain": chain,
        // Keep this ONLY if your backend requires token in body too:
        "token": token,
      };

      // ---- Debug logging (mask sensitive fields) ----
      String _mask(String s, {int head = 6, int tail = 6}) {
        if (s.length <= head + tail) return '***';
        return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
      }

      final masked = Map<String, dynamic>.from(requestBody);
      if (masked["token"] is String && (masked["token"] as String).isNotEmpty) {
        masked["token"] = _mask(masked["token"] as String);
      }

      // Print the endpoint, masked auth header, and sanitized body
      final maskedAuthHeader = _mask(token);
      print("🌐 POST /api/transaction/send");
      print("🔐 Authorization: Bearer $maskedAuthHeader");
      print("📦 Request body: ${jsonEncode(masked)}");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/transaction/send',
        token: token, // header Authorization
        requireAuth: true,
        body: requestBody,
      );

      print("📥 Raw response: ${response.statusCode} ${response.body}");
      final data = _handleResponse(response);
      print("✅ Transaction sent successfully");
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      print("🚨 Transaction error: $e");
      return AuthResponse.failure("Transaction failed: $e");
    }
  }
}
