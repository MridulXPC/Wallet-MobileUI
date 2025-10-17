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

/// Lightweight balance row for /api/get-balance/walletId/:walletId
/// Lightweight balance row for /api/get-balance/walletId/:walletId
class ChainBalance {
  final String blockchain; // e.g. "ETH"
  final String address; // wallet address for that chain
  final String token; // e.g. "ETH"
  final String symbol; // e.g. "ETH"
  final String balance; // keep as string (precision)
  final double? value; // may be 0 or null
  final String? nickname; // 👈 added support for user-given nickname

  const ChainBalance({
    required this.blockchain,
    required this.address,
    required this.token,
    required this.symbol,
    required this.balance,
    this.value,
    this.nickname,
  });

  factory ChainBalance.fromJson(Map<String, dynamic> json) {
    return ChainBalance(
      blockchain:
          json['blockchain']?.toString() ?? json['chain']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      token: json['token']?.toString() ??
          json['symbol']?.toString() ??
          json['blockchain']?.toString() ??
          '',
      symbol: json['symbol']?.toString() ??
          json['token']?.toString() ??
          json['blockchain']?.toString() ??
          '',
      balance: json['balance']?.toString() ?? '0',
      value: (json['value'] is num)
          ? (json['value'] as num).toDouble()
          : double.tryParse(json['value']?.toString() ?? ''),
      nickname: json['nickname']?.toString() ??
          json['walletName']?.toString() ??
          '', // 👈 pull nickname if present
    );
  }
}

class AuthService {
  static const String _baseUrl = 'https://vault-backend-cmjd.onrender.com';
  static const Duration _timeout = Duration(seconds: 30);

  // SharedPreferences keys
  static const String _spTokenKey = 'jwt_token';
  static const String _spUserIdKey = 'user_id';

  // Wallet ID (UUID) stored after create/import
  static const String _spWalletIdKey = 'wallet_id';

  // Wallet name cache (keyed by walletId)
  static const String _spWalletNamePrefix = 'wallet_name_';

  // Wallet address cache: wallet_address_<CHAIN>, e.g. wallet_address_BTC
  static const String _walletAddressKeyPrefix = 'wallet_address_';

  // Private HTTP client with timeout
  static final http.Client _client = http.Client();
  static void dispose() => _client.close();

  // ===================== HTTP CORE =====================

  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? token,
    bool requireAuth = true,
  }) async {
    token ??= await getStoredToken();
    print(token);

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

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    try {
      final data = jsonDecode(response.body);
      if (statusCode >= 200 && statusCode < 300) {
        if (data is Map<String, dynamic>) {
          return data;
        } else {
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

  // ---- WalletId saving helpers ----
  static Future<void> _saveWalletId(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spWalletIdKey, walletId);
  }

  static String? _extractWalletId(dynamic root) {
    if (root == null) return null;
    if (root is Map) {
      final data = root['data'];
      if (data is Map && data['walletId'] != null) {
        final v = data['walletId'].toString();
        if (v.isNotEmpty) return v;
      }
      final w1 = root['walletId']?.toString();
      if (w1 != null && w1.isNotEmpty) return w1;

      final wallet = (data is Map ? data['wallet'] : root['wallet']);
      if (wallet is Map) {
        final id = wallet['walletId']?.toString() ??
            wallet['_id']?.toString() ??
            wallet['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }

      final flatId = root['_id']?.toString() ?? root['id']?.toString();
      if (flatId != null && flatId.isNotEmpty) return flatId;
    }
    return null;
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

      // Save walletId (UUID) if present
      final walletId = _extractWalletId(data);
      if (walletId != null && walletId.isNotEmpty) {
        await _saveWalletId(walletId);
        debugPrint('💾 Stored walletId: $walletId');
      } else {
        debugPrint('⚠️ submitRecoveryPhrase: walletId not found in response');
      }

      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Failed to submit recovery phrase: $e');
    }
  }

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

  static Future<void> logout() async {
    try {
      await clearToken();
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('wallet_password'),
        prefs.remove('session_id'),
        prefs.remove('use_biometrics'),
        prefs.remove(_spUserIdKey),
        prefs.remove(_spWalletIdKey),
      ]);
    } catch (_) {}
  }

  static Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> validateToken([String? token]) async {
    try {
      token ??= await getStoredToken();
      if (token == null) return false;
      return token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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

  static Future<List<VaultToken>> fetchTokensByWallet({
    required String walletId,
    String? token,
  }) async {
    print('fetchTokensByWallet -> walletId: $walletId');

    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/token/get-tokens/$walletId',
        token: token,
        requireAuth: true,
      );

      final data = _handleResponse(response);

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
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .map(VaultToken.fromJson)
          .toList(growable: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch tokens for wallet $walletId: $e');
    }
  }

  // ===================== USER ID (local cache only) =====================

  static Future<String?> getStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_spUserIdKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getOrFetchUserId() async {
    final cached = await getStoredUserId();
    return (cached != null && cached.isNotEmpty) ? cached : null;
  }

  // ===================== WALLETS =====================
  /// ✅ NEW: Fetch all chain wallets for a given walletId
  /// This converts the `/api/wallet/get-wallets` response into a flat list of ChainBalance models
  static Future<List<ChainBalance>> fetchWalletsForUser(
      {required String walletId}) async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    final res = await _makeRequest(
      method: 'GET',
      endpoint: '/api/wallet/get-wallets',
      token: token,
      requireAuth: true,
    );

    final data = _handleResponse(res);

// handle nested structure
    final inner = (data['wallets'] is Map) ? data['wallets'] : data;
    final wallets =
        (inner['wallets'] as List?) ?? (data['data'] as List?) ?? [];

    final List<ChainBalance> rows = [];

    for (final w in wallets) {
      if (w is! Map) continue;
      final chains = (w['chains'] as List?) ?? [];
      for (final c in chains) {
        if (c is! Map) continue;

        final chain = (c['chain'] ?? '').toString();
        final address = (c['address'] ?? '').toString();
        final nickname =
            (c['nickname'] ?? w['name'] ?? w['walletName'] ?? '').toString();

        // Some chains might have nested "nativeAsset" data
        Map<String, dynamic>? native = (c['nativeAsset'] is Map)
            ? (c['nativeAsset'] as Map).cast<String, dynamic>()
            : null;

        rows.add(ChainBalance(
          blockchain: chain,
          address: address,
          token: native?['symbol']?.toString() ?? chain,
          symbol: native?['symbol']?.toString() ?? chain,
          balance: (native?['balance'] ?? '0').toString(),
          value: native?['usdValue'] is num
              ? (native?['usdValue'] as num).toDouble()
              : double.tryParse(native?['usdValue']?.toString() ?? '0'),
          nickname: nickname, // ✅ add nickname here
        ));
      }
    }

    // ✅ fallback if wallet object has direct 'chain' and 'address'
    for (final w in wallets) {
      if (w is! Map) continue;
      if (w['chains'] == null || (w['chains'] as List).isEmpty) {
        final chain = w['chain']?.toString();
        final address = w['address']?.toString();
        if (chain != null && chain.isNotEmpty && address != null) {
          rows.add(ChainBalance(
            blockchain: chain,
            address: address,
            token: chain,
            symbol: chain,
            balance: '0',
            value: 0.0,
            nickname: (w['nickname'] ?? w['walletName'] ?? '').toString(), // ✅
          ));
        }
      }
    }

    debugPrint('🔄 fetchWalletsForUser -> ${rows.length} chain entries found');
    return rows;
  }

  static Future<String?> getStoredWalletId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_spWalletIdKey);
    } catch (_) {
      return null;
    }
  }

  /// Prefer UUID walletId when present
  static String walletIdOf(Map m) {
    final wid = m['walletId']?.toString();
    if (wid != null && wid.isNotEmpty) return wid;
    return (m['_id'] ?? m['id'] ?? '').toString();
  }

  static String _normalizeChain(String? chain) {
    if (chain == null) return '';
    var u = chain.toUpperCase().trim();
    if (u.contains('-')) {
      u = u.split('-').last;
      if (u == 'LN') u = 'BTC';
    }
    if (u == 'TRX') return 'TRON';
    if (u == 'BNB-BNB') return 'BNB';
    if (u == 'SOL-SOL') return 'SOL';
    return u;
  }

  // ---- wallet name cache helpers ----
  static Future<void> _saveWalletName(String walletId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_spWalletNamePrefix$walletId', name);
  }

  static Future<Map<String, String>> _getAllStoredWalletNames() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_spWalletNamePrefix)) {
        final wid = k.substring(_spWalletNamePrefix.length);
        final v = prefs.getString(k);
        if (wid.isNotEmpty && v != null && v.isNotEmpty) map[wid] = v;
      }
    }
    return map;
  }

  /// GET /api/wallet/get-wallets
  static Future<List<Map<String, dynamic>>> fetchWallets(
      {String? token}) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

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

    // Normalize
    final normalized =
        walletsList.whereType<Map>().map<Map<String, dynamic>>((raw) {
      final m = Map<String, dynamic>.from(raw);

      // prefer UUID
      final wid = (m['walletId'] ?? m['id'] ?? m['_id'])?.toString();
      if (wid != null && wid.isNotEmpty) m['walletId'] = wid;

      // normalize name (backend may use walletName)
      final nm = (m['name'] ?? m['walletName'])?.toString();
      if (nm != null && nm.isNotEmpty) m['name'] = nm;

      // ensure a display address
      if ((m['address'] == null ||
              (m['address'] as String?)?.isEmpty == true) &&
          m['chains'] is List &&
          (m['chains'] as List).isNotEmpty) {
        final first = (m['chains'] as List).first;
        if (first is Map) {
          final addrDirect = first['address']?.toString();
          final addrNative = (first['nativeAsset'] is Map)
              ? (first['nativeAsset']['address']?.toString())
              : null;
          final addr = (addrDirect != null && addrDirect.isNotEmpty)
              ? addrDirect
              : (addrNative ?? '');
          if (addr.isNotEmpty) m['address'] = addr;
        }
      }

      // scrub secrets
      if (m['chains'] is List) {
        for (final c in (m['chains'] as List)) {
          if (c is Map && c['nativeAsset'] is Map) {
            final na = (c['nativeAsset'] as Map);
            na.remove('private_key');
            na.remove('privateKey');
            na.remove('seed_phrase');
            na.remove('mnemonic');
          }
        }
      }

      return m;
    }).toList(growable: false);

    // Overlay cached names
    final cachedNames = await _getAllStoredWalletNames();
    for (var i = 0; i < normalized.length; i++) {
      final wid = walletIdOf(normalized[i]);
      final cached = cachedNames[wid];
      if (cached != null && cached.isNotEmpty) {
        normalized[i]['name'] = cached;
        normalized[i]['walletName'] = cached;
      }
    }

    return normalized;
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

  static Future<String?> getOrFetchWalletAddress({String? chain}) async {
    final cached = await getStoredWalletAddress(chain: chain);
    if (cached != null && cached.isNotEmpty) return cached;

    final walletsResp = await fetchWallets();
    final address = _extractAddressForChain(walletsResp, chain: chain);

    if (address != null && address.isNotEmpty) {
      await _saveWalletAddress(address, chain: chain);
      return address;
    }

    debugPrint(
        '⚠️ getOrFetchWalletAddress: no address found for chain=${_normalizeChain(chain)}');
    return null;
  }

  static Future<String?> getWalletAddressForChain(String chain) async {
    final wallets = await fetchWallets();
    return _extractAddressForChain(wallets, chain: chain);
  }

  static String? _extractAddressForChain(dynamic walletsResp, {String? chain}) {
    final want = _normalizeChain(chain);

    if (walletsResp is List) {
      final list = walletsResp
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final pickedWallet = _pickWallet(list, chain: want);
      if (pickedWallet != null) {
        final addrFromPicked = _searchChainsForAddress(
          (pickedWallet['chains'] as List?) ?? const [],
          want,
        );
        if (addrFromPicked != null && addrFromPicked.isNotEmpty) {
          return addrFromPicked;
        }
        final direct = (pickedWallet['address'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) return direct;
      }
      for (final w in list) {
        final addr =
            _searchChainsForAddress((w['chains'] as List?) ?? const [], want) ??
                (w['address'] as String?)?.trim();
        if (addr != null && addr.isNotEmpty) return addr;
      }
      return null;
    }

    if (walletsResp is Map && walletsResp['wallets'] is List) {
      return _extractAddressForChain(walletsResp['wallets'], chain: want);
    }

    if (walletsResp is Map && walletsResp['chains'] is List) {
      final addr =
          _searchChainsForAddress(walletsResp['chains'] as List, want) ??
              (walletsResp['address'] as String?)?.trim();
      return (addr != null && addr.isNotEmpty) ? addr : null;
    }

    debugPrint(
        '⚠️ _extractAddressForChain: unexpected response shape: ${walletsResp.runtimeType}');
    return null;
  }

  /// Safely find the address for a specific blockchain chain.
  /// - [chains] is a list of maps returned by the API (each with 'chain' & 'address').
  /// - [want] is the chain code you are looking for (e.g. 'BTC', 'TRX', 'ETH').
  ///
  /// Returns the matching address if found; otherwise returns the first valid address (fallback).
  static String? _searchChainsForAddress(List chains, String want) {
    try {
      if (chains.isEmpty) return null;

      String? fallbackAddress;

      for (final c in chains) {
        if (c is! Map) continue;

        final m = c.cast<String, dynamic>();

        final chainCode = (m['chain'] as String?)?.toUpperCase().trim() ?? '';
        final normalized = _normalizeChain(chainCode);
        final address = (m['address'] as String?)?.trim();

        if (address != null && address.isNotEmpty) {
          // store first valid address as fallback
          fallbackAddress ??= address;

          // if no specific chain requested, return first valid one
          if (want.isEmpty) return address;

          // if chain matches, return that address
          if (normalized == want.toUpperCase()) {
            return address;
          }
        }
      }

      // fallback if no exact match found
      return fallbackAddress;
    } catch (e, st) {
      debugPrint('❌ _searchChainsForAddress error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// POST /api/wallet/create-single-chain
  /// Creates a new single-chain wallet address for an existing walletId
  /// POST /api/wallet/create-single-chain
  /// Creates a new single-chain wallet address for an existing walletId
  /// POST /api/wallet/create-single-chain
  /// Creates a new single-chain wallet address for an existing walletId
  /// POST /api/wallet/create-single-chain
  /// Creates a new single-chain wallet address for an existing walletId
  /// POST /api/wallet/create-single-chain
  /// Creates a new single-chain wallet address for an existing walletId
  static Future<AuthResponse> createSingleChainWallet({
    required String mnemonic,
    required String chain,
    required String walletId,
    required String nickname, // 👈 mandatory field
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    // ✅ API expects these exact keys
    final body = {
      "mnemonic": mnemonic,
      "chain": chain,
      "walletId": walletId,
      "nickname": nickname,
    };

    const endpoint = '/api/wallet/create-single-chain';

    try {
      debugPrint('🌐 POST $endpoint');
      debugPrint('📦 Request body: ${jsonEncode(body)}');

      final res = await _makeRequest(
        method: 'POST',
        endpoint: endpoint,
        token: token,
        requireAuth: true,
        body: body,
      );

      debugPrint('📥 Raw response: ${res.statusCode}');
      debugPrint('🧾 Response body: ${res.body}');
      if (res.statusCode >= 500) {
        throw ApiException('Server error ${res.statusCode}: ${res.body}');
      }

      final data = _handleResponse(res);

      // Optional: update stored walletId if backend returns one
      final newWalletId = _extractWalletId(data);
      if (newWalletId != null && newWalletId.isNotEmpty) {
        await _saveWalletId(newWalletId);
        debugPrint('💾 Updated walletId (single-chain): $newWalletId');
      }

      // Debug summary
      if (data is Map &&
          data['wallets'] is List &&
          data['wallets'].isNotEmpty) {
        final last = (data['wallets'] as List).last;
        debugPrint(
            '✅ Wallet created: ${last['chain']} → ${last['address']} (${last['nickname'] ?? 'no name'})');
      }

      return AuthResponse.success(data: data);
    } on ApiException catch (e) {
      debugPrint('🚨 ApiException: ${e.message}');
      return AuthResponse.failure('Server returned error: ${e.message}');
    } catch (e, st) {
      debugPrint('🚨 createSingleChainWallet error: $e\n$st');
      return AuthResponse.failure('Failed to create single-chain wallet: $e');
    }
  }

  /// DELETE /api/delete-single-chain
  /// Deletes a specific single-chain wallet by walletId + nickname
  /// POST /api/delete-single-chain
  /// Deletes a specific single-chain wallet by walletId + nickname
  /// DELETE /api/wallet/delete-single-chain
  static Future<AuthResponse> deleteSingleChainWallet({
    required String walletId,
    required String nickname,
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    final body = {
      "walletId": walletId,
      "nickname": nickname,
    };

    const endpoint = '/api/wallet/delete-single-chain'; // ✅ FIXED PATH

    try {
      debugPrint('🌐 DELETE $endpoint');
      debugPrint('🔐 Authorization: Bearer ***JWT***');
      debugPrint('📦 Body: ${jsonEncode(body)}');

      final request = http.Request('DELETE', Uri.parse('$_baseUrl$endpoint'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode(body);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint('📥 Raw response: ${response.statusCode}');
      debugPrint('🧾 Response body: ${response.body}');
      if (response.statusCode >= 500) {
        throw ApiException(
            'Server error ${response.statusCode}: ${response.body}');
      }

      final data = _handleResponse(response);
      debugPrint('✅ Deleted wallet nickname="$nickname" for ID=$walletId');

      return AuthResponse.success(data: data);
    } catch (e, st) {
      debugPrint('🚨 deleteSingleChainWallet error: $e\n$st');
      return AuthResponse.failure('Failed to delete wallet: $e');
    }
  }

  static Future<AuthResponse> sendTransaction({
    required String userId,
    required String walletAddress,
    required String toAddress,
    required String amount,
    required String chain,
    required String token,
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
      final data = _handleResponse(response);
      debugPrint("✅ ${data['message'] ?? 'Transaction sent successfully'}");
      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint("🚨 Transaction error: $e");
      return AuthResponse.failure("Transaction failed: $e");
    }
  }

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

  /// GET /api/transaction/history/:walletId
  static Future<List<TxRecord>> fetchTransactionHistoryByWallet({
    String? walletId, // optional, use stored if null
    String? chain,
    int? page,
    int? limit,
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    walletId ??= await getStoredWalletId();
    if (walletId == null || walletId.isEmpty) {
      throw const ApiException('walletId is required (not stored yet)');
    }

    final qp = <String, String>{};
    if (chain != null && chain.isNotEmpty) qp['chain'] = chain;
    if (page != null && page > 0) qp['page'] = page.toString();
    if (limit != null && limit > 0) qp['limit'] = limit.toString();
    final query = qp.isEmpty ? '' : '?${Uri(queryParameters: qp).query}';

    try {
      final endpoint =
          '/api/transaction/history/${Uri.encodeComponent(walletId)}$query';
      final res = await _makeRequest(
        method: 'GET',
        endpoint: endpoint,
        token: token,
        requireAuth: true,
      );

      final data = _handleResponse(res);
      final list = _TxJson.extractList(data);
      return list.map(TxRecord.fromJson).toList(growable: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Failed to fetch transaction history for wallet $walletId: $e',
      );
    }
  }

  static Future<List<TxRecord>> fetchTransactionHistory({
    String? walletId,
    String? address,
    String? chain,
    int? page,
    int? limit,
    String? token,
  }) async {
    if (walletId != null && walletId.isNotEmpty) {
      return fetchTransactionHistoryByWallet(
        walletId: walletId,
        chain: chain,
        page: page,
        limit: limit,
        token: token,
      );
    }

    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    final qp = <String, String>{};
    if (address != null && address.isNotEmpty) qp['address'] = address;
    if (chain != null && chain.isNotEmpty) qp['chain'] = chain;
    if (page != null && page > 0) qp['page'] = page.toString();
    if (limit != null && limit > 0) qp['limit'] = limit.toString();
    final query = qp.isEmpty ? '' : '?${Uri(queryParameters: qp).query}';

    try {
      final res = await _makeRequest(
        method: 'GET',
        endpoint: '/api/transaction/history$query',
        token: token,
        requireAuth: true,
      );
      final data = _handleResponse(res);
      final list = _TxJson.extractList(data);
      return list.map(TxRecord.fromJson).toList(growable: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch transaction history: $e');
    }
  }

  static Future<List<TxRecord>> fetchTransactionHistoryByAddress({
    required String address,
    String? chain,
    int? page,
    int? limit,
    String? token,
  }) {
    return fetchTransactionHistory(
      address: address,
      chain: chain,
      page: page,
      limit: limit,
      token: token,
    );
  }

  // ===================== SWAPS =====================

  static Future<AuthResponse> getSwapQuote({
    required String fromToken,
    required String toToken,
    required double amount,
    required String chain,
    required String destinationAddress, // ✅ new required field
    double? slippage,
  }) async {
    final jwt = await getStoredToken();
    if (jwt == null) {
      throw const ApiException('No authentication token available');
    }

    // ✅ New request body structure
    final body = {
      "fromToken": fromToken,
      "toToken": toToken,
      "amount": amount,
      "chain": chain,
      "destinationAddress": destinationAddress,
      if (slippage != null) "slippage": slippage,
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

      final Map<String, dynamic> data = _handleResponse(res);

      // ✅ Safely parse expected structure
      if (data['success'] != true || data['data'] == null) {
        throw ApiException(
          'Invalid swap quote response',
          statusCode: res.statusCode,
        );
      }

      final provider = data['provider'] ?? 'Unknown';
      final quoteData = data['data'] as Map<String, dynamic>;
      final fees = (quoteData['fees'] ?? {}) as Map<String, dynamic>;

      // ✅ Construct parsed response model
      final parsed = {
        "provider": provider,
        "fromToken": quoteData['fromToken'],
        "toToken": quoteData['toToken'],
        "amountIn": quoteData['amountIn'],
        "estimatedAmountOut": quoteData['estimatedAmountOut'],
        "router": quoteData['router'],
        "fees": {
          "asset": fees['asset'],
          "affiliate": fees['affiliate'],
          "outbound": fees['outbound'],
          "liquidity": fees['liquidity'],
          "total": fees['total'],
          "slippage_bps": fees['slippage_bps'],
          "total_bps": fees['total_bps'],
        },
      };

      return AuthResponse.success(data: parsed);
    }

    try {
      // ✅ First try the standard endpoint
      return await _call('/api/swaps/getQuote');
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        debugPrint("↩️ retrying without /api prefix...");
        return await _call('/swaps/getQuote');
      }
      rethrow;
    }
  }

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
        any ??= pk;
        if (want.isEmpty) return pk;
        if (normalized == want) return pk;
      }
    }
    return any;
  }

  static Future<Set<String>> getWalletSupportedChains(String walletId) async {
    throw UnimplementedError();
  }

  static Future<Map<String, double>> getWalletBalances(String walletId) async {
    throw UnimplementedError();
  }

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

  // ===================== EXPLORE =====================

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
      final data = (map['data'] ?? map) as Map<String, dynamic>;
      return ExploreData.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to explore $walletAddress: $e');
    }
  }

  // ===================== BALANCES =====================

  /// GET /api/get-balance/walletId/:walletId
  static Future<BalancesPayload> fetchBalancesAndTotal({
    String? token,
    String? walletId, // optional; falls back to stored
  }) async {
    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    walletId ??= await getStoredWalletId();
    if (walletId == null || walletId.isEmpty) {
      throw const ApiException('walletId is required (not stored yet)');
    }

    try {
      final endpoint =
          '/api/get-balance/walletId/${Uri.encodeComponent(walletId)}';
      debugPrint('🌐 GET $endpoint');

      final res = await _makeRequest(
        method: 'GET',
        endpoint: endpoint,
        token: token,
        requireAuth: true,
      );

      debugPrint('📥 Raw response: ${res.statusCode} ${res.body}');
      final map = _handleResponse(res);

      final dynamic data = map['data'] ?? map;

      List<dynamic> listDyn = const [];
      double totalUsd = 0.0;

      if (data is Map) {
        listDyn = (data['balances'] as List?) ?? const [];
        final t = data['total_balance'];
        if (t is num) totalUsd = t.toDouble();
        if (t is String) totalUsd = double.tryParse(t) ?? 0.0;

        if (totalUsd == 0.0 && listDyn.isNotEmpty) {
          for (final e in listDyn.whereType<Map>()) {
            final v = e['value'];
            if (v is num) totalUsd += v.toDouble();
            if (v is String) totalUsd += double.tryParse(v) ?? 0.0;
          }
        }
      } else if (data is List) {
        listDyn = data;
        for (final e in listDyn.whereType<Map>()) {
          final v = e['value'];
          if (v is num) totalUsd += v.toDouble();
          if (v is String) totalUsd += double.tryParse(v) ?? 0.0;
        }
      }

      final rows = listDyn
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .map((m) {
        if (!m.containsKey('nickname')) m['nickname'] = m['walletName'] ?? '';
        return ChainBalance.fromJson(m);
      }).toList(growable: false);

      return BalancesPayload(rows: rows, totalUsd: totalUsd);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to fetch balances: $e');
    }
  }

  /// PUT /api/wallet/name/:walletId
  static Future<AuthResponse> updateWalletName({
    String? walletId, // optional: falls back to stored walletId
    required String walletName,
    String? token,
  }) async {
    final name = walletName.trim();
    if (name.isEmpty) {
      throw const ApiException('walletName is required');
    }

    token ??= await getStoredToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token available');
    }

    walletId ??= await getStoredWalletId();
    if (walletId == null || walletId.isEmpty) {
      throw const ApiException('walletId is required (not stored yet)');
    }

    final endpoint = '/api/wallet/name/${Uri.encodeComponent(walletId)}';

    try {
      debugPrint('🌐 PUT $endpoint');
      debugPrint('📦 Body: {"walletName":"$name"}');

      final res = await _makeRequest(
        method: 'PUT',
        endpoint: endpoint,
        token: token,
        requireAuth: true,
        body: {'walletName': name},
      );

      debugPrint('📥 Raw response: ${res.statusCode} ${res.body}');
      final data = _handleResponse(res);

      // ✅ persist new name locally so fetchWallets() can overlay it
      await _saveWalletName(walletId, name);

      return AuthResponse.success(data: data);
    } on ApiException {
      rethrow;
    } catch (e) {
      return AuthResponse.failure('Failed to update wallet name: $e');
    }
  }

  static Future<List<ChainBalance>> fetchAllChainBalances({
    String? token,
    String? walletId,
  }) async {
    final payload = await fetchBalancesAndTotal(
      token: token,
      walletId: walletId,
    );
    return payload.rows;
  }

  static Future<Map<String, String>> fetchBalanceMapBySymbol({
    String? token,
    required String walletId,
  }) async {
    if (walletId.isEmpty) {
      throw const ApiException('walletId is required');
    }

    final rows = await fetchAllChainBalances(
      token: token,
      walletId: walletId,
    );

    final map = <String, String>{};
    for (final r in rows) {
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

  static Future<Map<String, double>> fetchSpotPrices({
    required List<String> symbols,
    String? token,
  }) async {
    token ??= await getStoredToken();
    if (token == null) {
      throw const ApiException('No authentication token available');
    }

    final query = Uri(queryParameters: {'symbols': symbols.join(',')}).query;

    final endpoints = <String>[
      '/api/market/prices',
      '/market/prices',
      '/api/market/spot-prices',
      '/market/spot-prices',
      '/api/token/prices',
      '/token/prices',
    ];

    Map<String, double>? _parsePrices(dynamic data) {
      if (data is Map && data['data'] is Map) {
        final m = (data['data'] as Map);
        return m.map((k, v) =>
            MapEntry(k.toString().toUpperCase(), (v as num).toDouble()));
      }
      if (data is Map) {
        final out = <String, double>{};
        for (final e in data.entries) {
          final v = e.value;
          if (v is num || (v is String && double.tryParse(v) != null)) {
            out[e.key.toString().toUpperCase()] =
                v is num ? v.toDouble() : double.parse(v as String);
          }
        }
        if (out.isNotEmpty) return out;
      }
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

    ApiException? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _makeRequest(
          method: 'GET',
          endpoint: '$ep?$query',
          token: token,
          requireAuth: true,
        );

        if (res.statusCode < 200 || res.statusCode >= 300) {
          continue;
        }

        dynamic bodyJson;
        try {
          bodyJson = jsonDecode(res.body);
        } catch (_) {
          continue;
        }

        final parsed = _parsePrices(bodyJson);
        if (parsed != null && parsed.isNotEmpty) {
          return parsed;
        }
      } on ApiException catch (e) {
        lastErr = e;
      } catch (_) {}
    }

    if (lastErr != null) {
      debugPrint(
          'fetchSpotPrices fallback: ${lastErr.message} (Status: ${lastErr.statusCode})');
    }
    return const <String, double>{};
  }
}

// ===================== TRANSACTIONS (model & helper) =====================

// lib/services/models/tx_record.dart
class TxRecord {
  final String? id;
  final String? type; // "SEND", "RECEIVE", "SWAP", ...
  final String? token; // "ETH", "USDT", ...
  final String? chain; // "ETH", "TRX", ...
  final String? amount; // "0.008"
  final String? txHash;
  final String? status; // "COMPLETED", "PENDING", ...
  final DateTime? createdAt; // parse from ISO string
  final String? fromAddress;
  final String? toAddress;
  final num? amountUsd; // optional (if backend sends it)
  final num? fee; // optional

  TxRecord({
    this.id,
    this.type,
    this.token,
    this.chain,
    this.amount,
    this.txHash,
    this.status,
    this.createdAt,
    this.fromAddress,
    this.toAddress,
    this.amountUsd,
    this.fee,
  });

  factory TxRecord.fromJson(Map<String, dynamic> j) => TxRecord(
        id: j['_id']?.toString(),
        type: j['type']?.toString(),
        token: j['token']?.toString(),
        chain: j['chain']?.toString(),
        amount: j['amount']?.toString(),
        txHash: j['txHash']?.toString(),
        status: j['status']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
        fromAddress: j['fromAddress']?.toString(),
        toAddress: j['toAddress']?.toString(),
        amountUsd: j['amountUsd'] is num ? j['amountUsd'] as num : null,
        fee: j['fee'] is num ? j['fee'] as num : null,
      );
}

extension _TxJson on Map<String, dynamic> {
  static List<Map<String, dynamic>> extractList(dynamic root) {
    List list;
    if (root is List) {
      list = root;
    } else if (root is Map && root['data'] is List) {
      list = root['data'];
    } else if (root is Map && root['transactions'] is List) {
      list = root['transactions'];
    } else if (root is Map && root['result'] is List) {
      list = root['result'];
    } else {
      list = const [];
    }
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}

// ===================== HTTP helper =====================

class HttpKit {
  static http.Client? _client;

  static http.Client get client {
    if (_client != null) return _client!;
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15);
    _client = IOClient(io);
    return _client!;
  }

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

/// Small model
class BalancesPayload {
  final List<ChainBalance> rows;
  final double totalUsd; // 0.0 if missing
  const BalancesPayload({required this.rows, required this.totalUsd});
}
