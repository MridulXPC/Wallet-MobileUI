// lib/core/support_chat_badge.dart
import 'package:flutter/foundation.dart';

class SupportChatBadge extends ChangeNotifier {
  SupportChatBadge._();
  static final SupportChatBadge instance = SupportChatBadge._();

  int _unreadAdmin = 0;
  int get unread => _unreadAdmin;

  void increment() {
    _unreadAdmin++;
    notifyListeners();
  }

  void clear() {
    if (_unreadAdmin == 0) return;
    _unreadAdmin = 0;
    notifyListeners();
  }

  void setTo(int v) {
    _unreadAdmin = v < 0 ? 0 : v;
    notifyListeners();
  }
}
