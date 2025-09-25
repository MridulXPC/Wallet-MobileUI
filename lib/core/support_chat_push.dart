// lib/core/support_chat_push.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/core/support_chat_badge.dart';

class SupportChatPush {
  SupportChatPush._();
  static final SupportChatPush instance = SupportChatPush._();

  IO.Socket? _socket;
  bool _connecting = false;
  bool _chatScreenOpen = false; // when true, don't badge-increment

  bool _authed = false;

  /// Call this early (e.g., after login or app start) or from TechSupportScreen.initState.
  Future<void> init() async {
    if (_socket != null || _connecting) return;
    _connecting = true;

    try {
      final jwt = await AuthService.getStoredToken();
      if (jwt == null || jwt.isEmpty) {
        _connecting = false;
        return;
      }

      const url = 'https://vault-backend-cmjd.onrender.com';
      final s = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .build(),
      );

      // Clean slate
      s.off('authenticated');
      s.off('auth-error');
      s.off('new-admin-message');
      s.off('message-received');

      s.onConnect((_) {
        s.emit('authenticate', {'token': jwt});
      });

      s.on('authenticated', (_) {});

      s.on('auth-error', (_) {});

      // Your backend should emit this for user clients when an admin posts.
      s.on('new-admin-message', (data) {
        // You may receive: { message: {...} } or direct object
        final msg = _extractMessage(data);
        if (msg == null) return;

        final isAdmin = _isAdminMsg(msg);
        if (!isAdmin) return;

        // If user isn't on the chat screen, bump the badge
        if (!_chatScreenOpen) {
          SupportChatBadge.instance.increment();
        }
      });

      // Defensive: if your backend also emits 'message-received' globally
      s.on('message-received', (data) {
        final msg = (data is Map) ? data['message'] : null;
        if (msg == null) return;
        if (!_isAdminMsg(msg)) return;
        if (!_chatScreenOpen) {
          SupportChatBadge.instance.increment();
        }
      });

      s.onDisconnect((_) {});

      _socket = s;
      s.connect();
    } catch (_) {
      // swallow; keep app stable
    } finally {
      _connecting = false;
    }
  }

  /// Call this from SupportChatScreen when screen opens/closes.
  void setChatScreenOpen(bool isOpen) {
    _chatScreenOpen = isOpen;
    if (isOpen) {
      // When opening the chat, unread should disappear immediately
      SupportChatBadge.instance.clear();
    }
  }

  Map<String, dynamic>? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['message'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['message'] as Map);
      }
      // Sometimes it can be the message itself
      return data;
    }
    return null;
  }

  bool _isAdminMsg(Map<String, dynamic> msg) {
    if (msg['isAdminMessage'] == true) return true;
    final sender = msg['sender'];
    if (sender is Map && sender['isAdmin'] == true) return true;
    return false;
  }
}
