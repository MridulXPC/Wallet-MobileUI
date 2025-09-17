// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptowallet/models/explore_model.dart';
import 'package:cryptowallet/models/token_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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

/// Lightweight balance row for /api/get-balance/get-balance
class ChainBalance {
  final String blockchain; // e.g. "ETH"
  final String address; // wallet address for that chain
  final String token; // e.g. "ETH"
  final String symbol; // e.g. "ETH"
  final String balance; // keep as string (precision)
  final double? value; // may be 0 or null

  const ChainBalance({
    required this.blockchain,
    required this.address,
    required this.token,
    required this.symbol,
    required this.balance,
    this.value,
  });

  factory ChainBalance.fromJson(Map<String, dynamic> json) {
    return ChainBalance(
      blockchain: json['blockchain']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0',
      value: (json['value'] is num)
          ? (json['value'] as num).toDouble()
          : double.tryParse(json['value']?.toString() ?? ''),
    );
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
    debugPrint(
        '⚠️ fetchTokens() is legacy. Prefer fetchTokensByWallet(walletId: ...)');
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
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => VaultToken.fromJson(e))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch tokens: $e');
    }
  }

  /// New: fetch tokens for a specific wallet id
  static Future<List<VaultToken>> fetchTokensByWallet({
    required String walletId,
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/token/get-tokens/$walletId', // wallet in path
        token: token,
        requireAuth: true,
      );

      final data = _handleResponse(response);

      // Normalize to a List<dynamic> WITHOUT calling List.from on a Map.
      List<dynamic> list;
      if (data is List) {
        list = data as List;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['tokens'] is List) {
        list = data['tokens'] as List<dynamic>;
      } else {
        list = const <dynamic>[];
      }

      return list
          .whereType<Map>() // Map<dynamic, dynamic>
          .map((e) => e.cast<String, dynamic>()) // -> Map<String, dynamic>
          .map((json) => VaultToken.fromJson(json)) // -> VaultToken
          .toList(growable: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch tokens for wallet $walletId: $e');
    }
  }

  // ===================== USER ID (local cache only; /auth/me removed) =====================

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

  /// Returns cached userId if present; NO network call anymore.
  static Future<String?> getOrFetchUserId() async {
    final cached = await getStoredUserId();
    return (cached != null && cached.isNotEmpty) ? cached : null;
  }

  // ===================== WALLETS: /api/wallet/get-wallets =====================

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

    // ✅ Print JWT for debugging
    debugPrint('🔑 JWT Token: $token');

    final res = await _makeRequest(
      method: 'GET',
      endpoint: '/api/wallet/get-wallets',
      token: token,
      requireAuth: true,
    );
    final data = _handleResponse(res);

    final dynamic payload = data['wallets'] ?? data['data'] ?? data;
    List walletsList;

    if (payload is List) {
      walletsList = payload;
    } else if (payload is Map && payload['wallets'] is List) {
      walletsList = payload['wallets'];
    } else {
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
        if (addrFromPicked != null && addrFromPicked.isNotEmpty) {
          return addrFromPicked;
        }
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
      final normalized = _normalizeChain(chainCode ?? '');
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
  static Future<AuthResponse> sendTransaction({
    required String userId,
    required String walletAddress,
    required String toAddress,
    required String amount, // keep as string to avoid precision issues
    required String chain, // e.g. "ETH"
    required String token, // e.g. "ETH", separate from chain
    String priority = "Standard",
  }) async {
    try {
      final jwt = await getStoredToken();
      if (jwt == null || jwt.isEmpty) {
        throw const ApiException("No authentication token available");
      }

      final requestBody = <String, dynamic>{
        "userID": userId,
        "walletAddress": walletAddress,
        "toAddress": toAddress,
        "amount": amount,
        "token": token,
        "priority": priority,
        "chain": chain,
      };

      debugPrint("🌐 POST /api/transaction/send");
      debugPrint("🔐 Authorization: Bearer ***JWT***");
      debugPrint("📦 Request body: ${jsonEncode(requestBody)}");

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/transaction/send',
        token: jwt,
        requireAuth: true,
        body: requestBody,
      );

      debugPrint("📥 Raw response: ${response.statusCode} ${response.body}");
      final data = _handleResponse(response); // throws ApiException on non-2xx

      // Expected keys: message, transaction{id, txHash, status}, success
      debugPrint("✅ ${data['message'] ?? 'Transaction sent successfully'}");
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint("🚨 Transaction error: $e");
      return AuthResponse.failure("Transaction failed: $e");
    }
  }

  /// Convenience: auto-fill userID & walletAddress from local cache/helpers.
  /// - Looks up cached userID (no network) and the wallet address for the chain.
  /// - Throws ApiException if either is unavailable.
  static Future<AuthResponse> sendTransactionUsingCache({
    required String toAddress,
    required String amount,
    required String chain,
    required String token,
    String priority = "Standard",
  }) async {
    final uid = await getOrFetchUserId();
    if (uid == null || uid.isEmpty) {
      throw const ApiException('No userID available (not cached).');
    }

    final fromAddress = await getOrFetchWalletAddress(chain: chain);
    if (fromAddress == null || fromAddress.isEmpty) {
      throw ApiException(
          'No walletAddress found for chain=${_normalizeChain(chain)}');
    }

    return sendTransaction(
      userId: uid,
      walletAddress: fromAddress,
      toAddress: toAddress,
      amount: amount,
      chain: chain,
      token: token,
      priority: priority,
    );
  }

  // ===================== SWAPS =====================

  /// POST /api/swaps/getQuote
  static Future<AuthResponse> getSwapQuote({
    required String fromToken,
    required String toToken,
    required double amount,
    required String chain,
    double? slippage,
  }) async {
    final jwt = await getStoredToken();
    if (jwt == null) {
      throw const ApiException('No authentication token available');
    }

    final body = {
      "fromToken": fromToken,
      "toToken": toToken,
      "amount": amount,
      "chain": chain,
      if (slippage != null) 'slippage': slippage, // send raw number
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
      return await _call('/api/swaps/getQuote');
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        debugPrint("↩️ retrying without /api prefix...");
        return await _call('/swaps/getQuote');
      }
      rethrow;
    }
  }

  /// POST /api/swaps/swap
  static Future<AuthResponse> swapTokens({
    required String walletId,
    required String fromToken,
    required String toToken,
    required double amount,
    required double slippage,
    required String chainI,
    required String privateKey,
  }) async {
    final jwt = await getStoredToken();
    if (jwt == null) {
      throw const ApiException('No authentication token available');
    }

    print(jwt);

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
      return await _call('/api/swaps/swap');
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        debugPrint("↩️ retrying without /api prefix...");
        return await _call('/swaps/swap');
      }
      rethrow;
    }
  }

  // ===================== WALLET SECRETS HELPERS =====================

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

  // Should return a Set of uppercase chain codes, e.g. {'ETH','TRON','BNB','BTC','SOL'}
  static Future<Set<String>> getWalletSupportedChains(String walletId) async {
    // TODO: call your backend, parse, and return as a Set<String>.
    // Return {} if unknown to allow all coins (no filtering).
    throw UnimplementedError();
  }

  // Should return balances keyed by coinId (matching CoinStore ids), e.g. {'ETH':1.23,'USDT-TRX':55.6}
  static Future<Map<String, double>> getWalletBalances(String walletId) async {
    // TODO: call your backend, parse map<String,double>
    // Return {} if unknown; UI will show zero balances.
    throw UnimplementedError();
  }

  /// Returns ONLY the private key for a given chain (or null if not found).
  static Future<String?> getPrivateKeyForChain(String chain) async {
    final want = _normalizeChain(chain);
    final wallets = await fetchWallets();

    for (final wRaw in wallets) {
      final w = wRaw.cast<String, dynamic>();
      final pk = _extractPrivateKeyFromChains(
              (w['chains'] as List?) ?? const [], want) ??
          _extractPrivateKeyFromMap(w);
      if (pk != null && pk.isNotEmpty) return pk;
    }
    return null;
  }

  /// Returns {'walletId': '...', 'private_key': '...'} for a given chain.
  static Future<Map<String, String>?> getWalletIdAndPrivateKeyForChain(
      String chain) async {
    final want = _normalizeChain(chain);
    final wallets = await fetchWallets();
    if (wallets.isEmpty) return null;

    final picked = _pickWallet(wallets, chain: want);

    if (picked != null) {
      final pk = _extractPrivateKeyFromChains(
              (picked['chains'] as List?) ?? const [], want) ??
          _extractPrivateKeyFromMap(picked);
      final id = picked['_id']?.toString();
      if (id != null && id.isNotEmpty && pk != null && pk.isNotEmpty) {
        return {'walletId': id, 'private_key': pk};
      }
    }

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

  // ===================== EXPLORE: /api/token/explore/:address =====================

  /// GET /api/token/explore/<walletAddress>
  /// Returns parsed [ExploreData] including balances and transactions.
  static Future<ExploreData> exploreAddress(
    String walletAddress, {
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    try {
      final res = await _makeRequest(
        method: 'GET',
        endpoint: '/api/token/explore/$walletAddress',
        token: token,
        requireAuth: true,
      );
      final map = _handleResponse(res);

      // The API wraps payload like: { success: true, data: { ... } }
      final data = (map['data'] ?? map) as Map<String, dynamic>;
      return ExploreData.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to explore $walletAddress: $e');
    }
  }

  // ===================== BALANCES =====================

  /// GET /api/get-balance/get-balance
  /// Returns a list like:
  /// [
  ///   { "blockchain":"ETH", "address":"0x...", "token":"ETH", "symbol":"ETH", "balance":"0.001...", "value":0 },
  ///   { "blockchain":"BNB", ... },
  ///   ...
  /// ]
// REPLACE your existing fetchAllChainBalances(...) with this pair:

  /// New: returns both rows + total in USD (handles old/new response shapes)
  static Future<BalancesPayload> fetchBalancesAndTotal({String? token}) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    try {
      debugPrint('🌐 GET /api/get-balance/get-balance');
      final res = await _makeRequest(
        method: 'GET',
        endpoint: '/api/get-balance/get-balance',
        token: token,
        requireAuth: true,
      );

      debugPrint('📥 Raw response: ${res.statusCode} ${res.body}');
      final map = _handleResponse(res);

      // The API wraps payload as:
      // { success: true, data: { balances:[...], total_balance:"245.00" } }
      // or older: { success:true, data: [ ... ] }
      final dynamic data = map['data'] ?? map;

      List<dynamic> listDyn = const [];
      double totalUsd = 0.0;

      if (data is Map) {
        listDyn = (data['balances'] as List?) ?? const [];
        final t = data['total_balance'];
        if (t is num) totalUsd = t.toDouble();
        if (t is String) totalUsd = double.tryParse(t) ?? 0.0;

        // Fallback if total not present → sum item "value"
        if (totalUsd == 0.0 && listDyn.isNotEmpty) {
          for (final e in listDyn.whereType<Map>()) {
            final v = e['value'];
            if (v is num) totalUsd += v.toDouble();
            if (v is String) totalUsd += double.tryParse(v) ?? 0.0;
          }
        }
      } else if (data is List) {
        listDyn = data;
        // Old shape without total; try sum of "value"
        for (final e in listDyn.whereType<Map>()) {
          final v = e['value'];
          if (v is num) totalUsd += v.toDouble();
          if (v is String) totalUsd += double.tryParse(v) ?? 0.0;
        }
      }

      final rows = listDyn
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .map(ChainBalance.fromJson)
          .toList(growable: false);

      return BalancesPayload(rows: rows, totalUsd: totalUsd);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch balances: $e');
    }
  }

  /// Back-compat: keeps your old signature working
  static Future<List<ChainBalance>> fetchAllChainBalances(
      {String? token}) async {
    final payload = await fetchBalancesAndTotal(token: token);
    return payload.rows;
  }

  /// Convenience: return { "ETH": "0.00195788941302871", "BNB": "0.0", ... }
  static Future<Map<String, String>> fetchBalanceMapBySymbol(
      {String? token}) async {
    final rows = await fetchAllChainBalances(token: token);
    final map = <String, String>{};
    for (final r in rows) {
      // Use symbol in uppercase as key (e.g., ETH, BNB, SOL, TRX)
      if (r.symbol.isNotEmpty) {
        map[r.symbol.toUpperCase()] = r.balance;
      } else if (r.token.isNotEmpty) {
        map[r.token.toUpperCase()] = r.balance;
      } else if (r.blockchain.isNotEmpty) {
        map[r.blockchain.toUpperCase()] = r.balance;
      }
    }
    return map;
  }

  // ===================== MARKET PRICES =====================

  /// Replace the whole fetchSpotPrices() with this version.
  static Future<Map<String, double>> fetchSpotPrices({
    required List<String>
        symbols, // e.g. ['BTC','ETH','USDT','TRX','BNB','SOL']
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    // Build query once
    final query = Uri(queryParameters: {'symbols': symbols.join(',')}).query;

    // Try several plausible endpoints (with and without /api)
    final endpoints = <String>[
      '/api/market/prices',
      '/market/prices',
      '/api/market/spot-prices',
      '/market/spot-prices',
      '/api/token/prices',
      '/token/prices',
    ];

    // Helper: parse various shapes into Map<String,double>
    Map<String, double>? _parsePrices(dynamic data) {
      // Case A: { "success": true, "data": { "BTC": 123.4, ... } }
      if (data is Map && data['data'] is Map) {
        final m = (data['data'] as Map);
        return m.map((k, v) =>
            MapEntry(k.toString().toUpperCase(), (v as num).toDouble()));
      }
      // Case B: { "BTC": 123.4, "ETH": 234.5 }
      if (data is Map) {
        // ensure all values are numeric
        final out = <String, double>{};
        for (final entry in data.entries) {
          final v = entry.value;
          if (v is num || (v is String && double.tryParse(v) != null)) {
            out[entry.key.toString().toUpperCase()] =
                v is num ? v.toDouble() : double.parse(v as String);
          }
        }
        if (out.isNotEmpty) return out;
      }
      // Case C: [ {"symbol":"BTC","price":123.4}, ... ]
      if (data is List) {
        final out = <String, double>{};
        for (final e in data) {
          if (e is Map) {
            final sym = (e['symbol'] ?? e['code'] ?? e['ticker'])?.toString();
            final price = e['price'] ?? e['priceUsd'] ?? e['usd'];
            double? p;
            if (price is num) p = price.toDouble();
            if (price is String) p = double.tryParse(price);
            if (sym != null && p != null) out[sym.toUpperCase()] = p;
          }
        }
        if (out.isNotEmpty) return out;
      }
      return null;
    }

    // Try each endpoint until one works
    ApiException? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _makeRequest(
          method: 'GET',
          endpoint: '$ep?$query',
          token: token,
          requireAuth: true,
        );

        // Accept only 2xx; otherwise try next endpoint
        if (res.statusCode < 200 || res.statusCode >= 300) {
          // If body isn't JSON, skip quietly (prevents "Invalid response format (404)")
          continue;
        }

        // Try to JSON-decode and parse shapes
        dynamic bodyJson;
        try {
          bodyJson = jsonDecode(res.body);
        } catch (_) {
          // Not JSON → try next endpoint
          continue;
        }

        final parsed = _parsePrices(bodyJson);
        if (parsed != null && parsed.isNotEmpty) {
          return parsed;
        }
        // Parsed but empty → try next
      } on ApiException catch (e) {
        lastErr = e;
        // keep looping to try the next endpoint
      } catch (e) {
        // non-API error; keep trying others
      }
    }

    // Nothing worked → return empty map (don’t hard-fail UI)
    if (lastErr != null) {
      debugPrint(
          'fetchSpotPrices fallback: ${lastErr.message} (Status: ${lastErr.statusCode})');
    }
    return const <String, double>{};
  }
}

// ===================== HTTP helper =====================

class HttpKit {
  static http.Client? _client;

  /// One shared client with sane timeouts.
  static http.Client get client {
    if (_client != null) return _client!;
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15);
    _client = IOClient(io);
    return _client!;
  }

  /// Retry wrapper for idempotent GET/HEAD/OPTIONS
  static Future<http.Response> getWithRetry(
    Uri url, {
    Map<String, String>? headers,
    int maxAttempts = 3,
    Duration perAttemptTimeout = const Duration(seconds: 15),
  }) async {
    int attempt = 0;
    Object? lastErr;
    StackTrace? lastSt;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final resp =
            await client.get(url, headers: headers).timeout(perAttemptTimeout);
        return resp;
      } catch (e, st) {
        lastErr = e;
        lastSt = st;
      }

      // backoff: 0.5s, 1s, 2s
      final num n = (500 * (1 << (attempt - 1))).clamp(500, 2000);
      final int backoffMs = n.toInt();
      await Future.delayed(Duration(milliseconds: backoffMs));
    }

    if (lastErr != null && lastSt != null) {
      Error.throwWithStackTrace(lastErr!, lastSt);
    }
    throw Exception('Request failed');
  }
}

/// Add near your other small models in api_service.dart
class BalancesPayload {
  final List<ChainBalance> rows;
  final double totalUsd; // 0.0 if missing
  const BalancesPayload({required this.rows, required this.totalUsd});
}
