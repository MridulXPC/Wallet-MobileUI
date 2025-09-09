import 'dart:convert';

import 'package:cryptowallet/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import your bip39 or seed generator if you have one

import 'package:cryptowallet/stores/wallet_store.dart'; // for LocalWallet

class WalletFlow {
  // Load all wallets you have stored locally.
  static Future<List<LocalWallet>> loadLocalWallets() async {
    // TODO: replace with your real persistence.
    final prefs = await SharedPreferences.getInstance();
    // Example shape; adapt to your real storage
    final json = prefs.getString('local_wallets') ?? '[]';
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return list
        .map((m) => LocalWallet(
              id: m['id'],
              name: m['name'],
              primaryAddress: m['primaryAddress'] ?? '',
              createdAt: DateTime.parse(m['createdAt']),
            ))
        .toList();
  }

  static Future<void> _saveLocalWallets(List<LocalWallet> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    final list = wallets
        .map((w) => {
              'id': w.id,
              'name': w.name,
              'primaryAddress': w.primaryAddress,
              'createdAt': w.createdAt.toIso8601String(),
            })
        .toList();
    await prefs.setString('local_wallets', jsonEncode(list));
  }

  /// Creates a new wallet:
  ///  - generates mnemonic
  ///  - calls backend /api/wallet/create
  ///  - stores {id/name/address} locally
  static Future<LocalWallet> createNewWallet({String? name}) async {
    // 1) generate mnemonic (or fetch from backend if you do that there)
    final mnemonic = /* your generator */ '... 12/24 words ...';

    // 2) tell backend to create (saves chain wallets etc.)
    final resp = await AuthService.submitRecoveryPhrase(phrase: mnemonic);
    if (!resp.success) {
      throw 'Wallet creation failed: ${resp.message ?? 'unknown error'}';
    }

    // 3) parse wallet id/address from resp.data (adapt to your API shape)
    final data = resp.data ?? {};
    final walletId = data['wallet']?['_id']?.toString() ??
        data['result']?['walletId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    // pick an address to show (adapt to your backend shape)
    final String primaryAddress = data['wallet']?['address']?.toString() ??
        data['address']?.toString() ??
        '';

    // 4) append locally
    final current = await loadLocalWallets();
    final local = LocalWallet(
      id: walletId,
      name: name ?? 'My Wallet',
      primaryAddress: primaryAddress,
      createdAt: DateTime.now(),
    );
    final next = [...current, local];
    await _saveLocalWallets(next);

    return local;
  }

  // Optional helper used in your screen bootstrap
  static Future<LocalWallet> ensureDefaultWallet() async {
    final list = await loadLocalWallets();
    if (list.isNotEmpty) return list.first;
    return createNewWallet(name: 'My Wallet');
  }
}
