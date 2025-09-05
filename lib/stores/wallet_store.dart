import 'dart:convert';
import 'dart:math';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/auth_service.dart';

class Wallet {
  final String id; // local id
  final String name; // My Wallet, My Wallet 1, ...
  final String mnemonic; // stored locally
  final DateTime createdAt;
  final Map<String, dynamic>? backend; // optional: backend response

  const Wallet({
    required this.id,
    required this.name,
    required this.mnemonic,
    required this.createdAt,
    this.backend,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mnemonic': mnemonic,
        'createdAt': createdAt.toIso8601String(),
        'backend': backend,
      };

  static Wallet fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'] as String,
        name: j['name'] as String,
        mnemonic: j['mnemonic'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        backend: j['backend'] as Map<String, dynamic>?,
      );
}

class WalletStore extends ChangeNotifier {
  static const _kWallets = 'wallets_v1';
  static const _kActive = 'active_wallet_id_v1';

  final List<Wallet> _wallets = [];
  String? _activeId;

  List<Wallet> get wallets => List.unmodifiable(_wallets);
  String? get activeWalletId => _activeId;

  // ---------- persistence ----------
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kWallets);
    _activeId = prefs.getString(_kActive);
    _wallets.clear();
    if (raw != null && raw.isNotEmpty) {
      final List list = jsonDecode(raw) as List;
      _wallets
          .addAll(list.map((e) => Wallet.fromJson(e as Map<String, dynamic>)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kWallets,
      jsonEncode(_wallets.map((w) => w.toJson()).toList()),
    );
    if (_activeId != null) {
      await prefs.setString(_kActive, _activeId!);
    } else {
      await prefs.remove(_kActive);
    }
  }

  // ---------- helpers ----------
  String _genId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

  String _nextName() {
    if (_wallets.isEmpty) return 'My Wallet';
    // reserve unique: My Wallet, My Wallet 1, 2, ...
    final existing = _wallets.map((w) => w.name.toLowerCase()).toSet();
    int i = 1;
    while (true) {
      final candidate = i == 0 ? 'my wallet' : 'my wallet $i';
      if (!existing.contains(candidate)) {
        return i == 0 ? 'My Wallet' : 'My Wallet $i';
      }
      i++;
    }
  }

  // ---------- actions ----------
  /// Create seed (BIP39) -> send to backend -> store locally -> set active
  Future<Wallet> createAndSendToBackend() async {
    final mnemonic = bip39.generateMnemonic(strength: 128);
    final name = _nextName();

    final resp = await AuthService.submitRecoveryPhrase(phrase: mnemonic);
    // (optional) you can inspect resp.success here

    final w = Wallet(
      id: _genId(),
      name: name,
      mnemonic: mnemonic,
      createdAt: DateTime.now(),
      backend: resp.data,
    );

    _wallets.add(w);
    _activeId = w.id;
    await _save();
    notifyListeners();
    return w;
  }

  Future<void> setActive(String walletId) async {
    if (_activeId == walletId) return;
    _activeId = walletId;
    await _save();
    notifyListeners();
  }
}
