import 'dart:convert';
import 'dart:io';
import 'package:cryptowallet/models/token_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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

  // (Legacy) kept for backwards compatibility if anything still reads them
  static const String _spWalletIdKey = 'wallet_id';

  // Wallet address cache: wallet_address_<CHAIN>, e.g. wallet_address_BTC
  static const String _walletAddressKeyPrefix = 'wallet_address_';

  // Private HTTP client with timeout
  static final http.Client _client = http.Client();
  static void dispose() => _client.close();

  // ===================== HTTP CORE =====================

  /// Generic HTTP request handler (auto-attaches JWT in Authorization header)
  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? token,
    bool requireAuth = true, // default: most endpoints require auth
  }) async {
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
          // If your backend expects body on DELETE, add `body: jsonBody`.
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
      final data = jsonDecode(response.body);
      if (statusCode >= 200 && statusCode < 300) {
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          // Some endpoints might return non-map JSON. Wrap it.
          return {'data': data};
        }
      } else {
        final map = data is Map ? data : <String, dynamic>{};
        final message = map['message'] ?? map['error'] ?? 'Request failed';
        throw ApiException(
          message.toString(),
          statusCode: statusCode,
          details: map.cast<String, dynamic>(),
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Invalid response format', statusCode: statusCode);
    }
  }

  // ===================== TOKEN STORAGE =====================

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

  // ===================== AUTH FLOWS =====================

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
        requireAuth: false,
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
        token: token,
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
        token: token,
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
        requireAuth: false,
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
        prefs.remove(_spUserIdKey),
        prefs.remove(_spWalletIdKey), // legacy
        // Clear all cached wallet addresses (basic sweep)
        // If you have a fixed list of chains, remove those exact keys.
        // Here we leave them as-is to avoid scanning keys.
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
        token: currentToken,
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

  // ===================== TOKENS (ASSETS) =====================

  static Future<List<VaultToken>> fetchTokens({String? token}) async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/token/get-tokens',
        token: token,
        requireAuth: true,
      );

      final data = _handleResponse(response);
      final List<dynamic> list =
          (data['data'] as List?) ?? (data['tokens'] as List?) ?? const [];
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

  // ===================== USER: /api/auth/me =====================

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

  // ===================== WALLETS: /api/wallet/get-wallets =====================

  /// (Legacy) kept in case older code still depends on id caching.
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

  /// Normalize symbol → backend chain codes for wallet selection & caching.
  /// Also collapses things like "USDT-ETH" -> "ETH", "BTC-LN" -> "BTC".
  static String _normalizeChain(String? chain) {
    if (chain == null) return '';
    var u = chain.toUpperCase().trim();
    if (u.contains('-')) {
      // Keep L1 base (e.g., "USDT-ETH" -> "ETH")
      u = u.split('-').last;
      if (u == 'LN') u = 'BTC'; // BTC-LN -> BTC
    }
    if (u == 'TRX') return 'TRON';
    if (u == 'BNB-BNB') return 'BNB';
    if (u == 'SOL-SOL') return 'SOL';
    return u;
  }

  /// GET /api/wallet/get-wallets (returns list of wallets or {wallets:[...]})
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

    // Accept both shapes: {wallets:[...]} or [...]
    final dynamic payload = data['wallets'] ?? data['data'] ?? data;
    List walletsList;

    if (payload is List) {
      walletsList = payload;
    } else if (payload is Map && payload['wallets'] is List) {
      walletsList = payload['wallets'];
    } else {
      // Unexpected shape; log and treat as empty
      debugPrint('⚠️ fetchWallets: unexpected shape: ${payload.runtimeType}');
      walletsList = const [];
    }

    return walletsList
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Prefer a wallet supporting target chain; else pick most recently updated.
  static Map<String, dynamic>? _pickWallet(
    List<Map<String, dynamic>> wallets, {
    String? chain,
  }) {
    final want = _normalizeChain(chain);

    Map<String, dynamic>? best;
    DateTime? bestTime;

    for (final w in wallets) {
      final chains = (w['chains'] as List?) ?? const [];
      final supportsWanted = want.isEmpty
          ? true
          : chains.any((c) {
              final m = (c as Map).cast<String, dynamic>();
              final cc = (m['chain']?.toString().toUpperCase() ?? '');
              return _normalizeChain(cc) == want;
            });

      if (!supportsWanted) continue;

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

  // ---------- Wallet address cache (per chain) ----------

  static Future<void> _saveWalletAddress(String address,
      {String? chain}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_walletAddressKeyPrefix${_normalizeChain(chain)}';
    await prefs.setString(key, address);
  }

  static Future<String?> getStoredWalletAddress({String? chain}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_walletAddressKeyPrefix${_normalizeChain(chain)}';
    return prefs.getString(key);
  }

  /// Returns cached walletAddress (per chain) if present; else fetch & cache.
  static Future<String?> getOrFetchWalletAddress({String? chain}) async {
    // 1) Try per-chain cache
    final cached = await getStoredWalletAddress(chain: chain);
    if (cached != null && cached.isNotEmpty) return cached;

    // 2) Fetch from API
    final walletsResp = await fetchWallets();

    // 3) Extract address for requested chain
    final address = _extractAddressForChain(walletsResp, chain: chain);

    if (address != null && address.isNotEmpty) {
      await _saveWalletAddress(address, chain: chain);
      return address;
    }

    debugPrint(
        '⚠️ getOrFetchWalletAddress: no address found for chain=${_normalizeChain(chain)}');
    return null;
  }

  /// Convenience: get the address for a given chain (no caching)
  static Future<String?> getWalletAddressForChain(String chain) async {
    final wallets = await fetchWallets();
    return _extractAddressForChain(wallets, chain: chain);
  }

  /// Extract the best address for a chain from wallets response (robust to shape).
  static String? _extractAddressForChain(dynamic walletsResp, {String? chain}) {
    final want = _normalizeChain(chain);

    // Shape A: List of wallet maps
    if (walletsResp is List) {
      final list = walletsResp
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      // Prefer a wallet that supports the chain
      final pickedWallet = _pickWallet(list, chain: want);
      if (pickedWallet != null) {
        final addrFromPicked = _searchChainsForAddress(
          (pickedWallet['chains'] as List?) ?? const [],
          want,
        );
        if (addrFromPicked != null && addrFromPicked.isNotEmpty)
          return addrFromPicked;
        // Fallback: some backends put 'address' at wallet level
        final direct = (pickedWallet['address'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) return direct;
      }
      // As an ultimate fallback, scan all wallets for first address
      for (final w in list) {
        final addr =
            _searchChainsForAddress((w['chains'] as List?) ?? const [], want) ??
                (w['address'] as String?)?.trim();
        if (addr != null && addr.isNotEmpty) return addr;
      }
      return null;
    }

    // Shape B: Map with "wallets": [...]
    if (walletsResp is Map && walletsResp['wallets'] is List) {
      return _extractAddressForChain(walletsResp['wallets'], chain: want);
    }

    // Shape C: Single wallet map
    if (walletsResp is Map && walletsResp['chains'] is List) {
      final addr =
          _searchChainsForAddress(walletsResp['chains'] as List, want) ??
              (walletsResp['address'] as String?)?.trim();
      return (addr != null && addr.isNotEmpty) ? addr : null;
    }

    // Unknown shape
    debugPrint(
        '⚠️ _extractAddressForChain: unexpected response shape: ${walletsResp.runtimeType}');
    return null;
  }

  static String? _searchChainsForAddress(List chains, String want) {
    String? any;
    for (final c in chains) {
      if (c is! Map) continue;
      final m = c.cast<String, dynamic>();
      final chainCode = (m['chain'] as String?)?.toUpperCase().trim();
      final normalized = _normalizeChain(chainCode);
      final address = (m['address'] as String?)?.trim();

      if (address != null && address.isNotEmpty) {
        any ??= address; // keep first valid as fallback
        if (want.isEmpty) return address;
        if (normalized == want) return address;
      }
    }
    return any; // fallback to first found address if exact match not found
  }

  // ===================== TRANSACTIONS =====================

  /// POST /api/transaction/send
  /// Header: Authorization: Bearer <jwt> (mandatory)
  /// Body: userID, walletAddress, toAddress, amount, chain, priority (optional)
  /// NOTE: If your backend also expects the JWT in the body, keep `"token": token`.
  static Future<AuthResponse> sendTransaction({
    required String userId,
    required String walletAddress, // ✅ backend wants walletAddress
    required String toAddress,
    required String amount,
    required String chain,
    String priority = "yes",
    String? coinSymbol, // ✅ e.g. "BTC", "ETH" (not the JWT)
  }) async {
    try {
      final jwt = await getStoredToken();
      if (jwt == null) {
        throw const ApiException("No authentication token available");
      }

      // Build request body
      final requestBody = <String, dynamic>{
        "userID": userId,
        "walletAddress": walletAddress, // ✅ correct key
        "toAddress": toAddress,
        "amount": amount,
        "priority": priority,
        "chain": chain, // keep as passed
        "token": coinSymbol ?? chain, // ✅ coin symbol, not JWT
      };

      // ---- Debug logging ----
      debugPrint("🌐 POST /api/transaction/send");
      debugPrint("🔐 Authorization: Bearer ***JWT***");
      debugPrint("📦 Request body: ${jsonEncode(requestBody)}");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/transaction/send',
        token: jwt, // ✅ JWT only in header
        requireAuth: true,
        body: requestBody,
      );

      debugPrint("📥 Raw response: ${response.statusCode} ${response.body}");
      final data = _handleResponse(response);
      debugPrint("✅ Transaction sent successfully");
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint("🚨 Transaction error: $e");
      return AuthResponse.failure("Transaction failed: $e");
    }
  }

// ===================== SWAPS =====================

  /// POST /swaps/getQuote
  /// Header: Authorization: Bearer <jwt>
  /// Body: { fromToken, toToken, amount, chain }
// --- QUOTES ---------------------------------------------------------------
  static Future<AuthResponse> getSwapQuote({
    required String fromToken,
    required String toToken,
    required double amount,
    required String chain,
  }) async {
    final jwt = await getStoredToken();
    if (jwt == null) {
      throw const ApiException('No authentication token available');
    }

    final body = {
      "fromToken": fromToken,
      "toToken": toToken,
      "amount": amount, // backend expects number
      "chain": chain, // e.g. "BTC", "ETH", "TRON"
    };

    Future<AuthResponse> _call(String endpoint) async {
      debugPrint("🌐 POST $endpoint");
      debugPrint("🔐 Authorization: Bearer ***JWT***");
      debugPrint("📦 Request body: ${jsonEncode(body)}");

      final res = await _makeRequest(
        method: 'POST',
        endpoint: endpoint,
        token: jwt,
        requireAuth: true,
        body: body,
      );

      debugPrint("📥 Raw response: ${res.statusCode} ${res.body}");
      final data = _handleResponse(res);
      return AuthResponse.success(data: data);
    }

    try {
      // primary (correct) path
      return await _call('/api/swaps/getQuote');
    } on ApiException catch (e) {
      // defensive: try non-/api once if server is mounted differently
      if (e.statusCode == 404 || e.statusCode == 405) {
        debugPrint("↩️ retrying without /api prefix...");
        return await _call('/swaps/getQuote');
      }
      rethrow;
    }
  }

  /// POST /swaps/swap
  /// Header: Authorization: Bearer <jwt>
  /// Body:
  /// {
  ///   "walletId": "",
  ///   "fromToken": "",
  ///   "toToken": "",
  ///   "amount": 8,
  ///   "slippage": 1,
  ///   "chainI": "",
  ///   "private_key": ""
  /// }
// --- SWAP ---------------------------------------------------------------
  static Future<AuthResponse> swapTokens({
    required String walletId,
    required String fromToken,
    required String toToken,
    required double amount, // number
    required double slippage, // percent (e.g., 1 = 1%)
    required String chainI, // e.g. "BTC", "ETH", "TRON"
    required String privateKey,
  }) async {
    final jwt = await getStoredToken();
    if (jwt == null) {
      throw const ApiException('No authentication token available');
    }

    final body = {
      "walletId": walletId,
      "fromToken": fromToken,
      "toToken": toToken,
      "amount": amount,
      "slippage": slippage,
      "chainI": chainI,
      "private_key": privateKey,
    };

    Future<AuthResponse> _call(String endpoint) async {
      debugPrint("🌐 POST $endpoint");
      debugPrint("🔐 Authorization: Bearer ***JWT***");
      debugPrint("📦 Request body: ${jsonEncode(body)}");

      final res = await _makeRequest(
        method: 'POST',
        endpoint: endpoint,
        token: jwt,
        requireAuth: true,
        body: body,
      );

      debugPrint("📥 Raw response: ${res.statusCode} ${res.body}");
      final data = _handleResponse(res);
      return AuthResponse.success(data: data);
    }

    try {
      // primary (correct) path
      return await _call('/api/swaps/swap');
    } on ApiException catch (e) {
      // defensive: try non-/api once
      if (e.statusCode == 404 || e.statusCode == 405) {
        debugPrint("↩️ retrying without /api prefix...");
        return await _call('/swaps/swap');
      }
      rethrow;
    }
  }
// ===================== WALLET SECRETS HELPERS (ADD THESE) =====================

  static String? _extractPrivateKeyFromMap(Map<String, dynamic> m) {
    final candidates = [
      m['private_key'],
      m['privateKey'],
      m['privKey'],
      m['pk'],
      (m['credentials'] is Map)
          ? (m['credentials'] as Map)['private_key']
          : null,
    ];
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _extractPrivateKeyFromChains(List chains, String want) {
    String? any;
    for (final c in chains) {
      if (c is! Map) continue;
      final m = c.cast<String, dynamic>();
      final chainCode = (m['chain'] as String?)?.toUpperCase().trim();
      final normalized = _normalizeChain(chainCode ?? '');
      final pk = _extractPrivateKeyFromMap(m);
      if (pk != null && pk.isNotEmpty) {
        any ??= pk; // keep first as fallback
        if (want.isEmpty) return pk;
        if (normalized == want) return pk;
      }
    }
    return any;
  }

  /// Returns ONLY the private key for a given chain (or null if not found).
  static Future<String?> getPrivateKeyForChain(String chain) async {
    final want = _normalizeChain(chain);
    final wallets = await fetchWallets();

    // Shape: list of wallet maps
    for (final wRaw in wallets) {
      final w = wRaw.cast<String, dynamic>();
      // try per-chain first
      final pk = _extractPrivateKeyFromChains(
              (w['chains'] as List?) ?? const [], want) ??
          _extractPrivateKeyFromMap(w); // wallet-level fallback
      if (pk != null && pk.isNotEmpty) return pk;
    }
    return null;
  }

  /// Returns {'walletId': '...', 'private_key': '...'} for a given chain.
  /// Picks the "best" wallet that supports the chain, falls back to first with creds.
  static Future<Map<String, String>?> getWalletIdAndPrivateKeyForChain(
      String chain) async {
    final want = _normalizeChain(chain);
    final wallets = await fetchWallets();
    if (wallets.isEmpty) return null;

    // Prefer the same selection logic as _pickWallet
    final picked = _pickWallet(wallets, chain: want);

    // Try picked wallet first
    if (picked != null) {
      final pk = _extractPrivateKeyFromChains(
              (picked['chains'] as List?) ?? const [], want) ??
          _extractPrivateKeyFromMap(picked);
      final id = picked['_id']?.toString();
      if (id != null && id.isNotEmpty && pk != null && pk.isNotEmpty) {
        return {'walletId': id, 'private_key': pk};
      }
    }

    // Otherwise scan all
    for (final wRaw in wallets) {
      final w = wRaw.cast<String, dynamic>();
      final pk = _extractPrivateKeyFromChains(
              (w['chains'] as List?) ?? const [], want) ??
          _extractPrivateKeyFromMap(w);
      final id = w['_id']?.toString();
      if (id != null && id.isNotEmpty && pk != null && pk.isNotEmpty) {
        return {'walletId': id, 'private_key': pk};
      }
    }

    return null;
  }
}
