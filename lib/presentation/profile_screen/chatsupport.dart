// lib/presentation/support/support_chat_screen.dart
import 'dart:typed_data';
import 'package:cryptowallet/core/support_chat_badge.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:cryptowallet/services/api_service.dart'; // must expose getStoredToken()
// <-- global unread badge

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  IO.Socket? _socket;
  bool _connecting = false;
  bool _authenticated = false;
  bool _loadingHistory = false;
  bool _initializing = true;
  String? _chatId;
  String? _jwt;

  final List<_Attachment> _draftAttachments = <_Attachment>[];
  final List<_Msg> _messages = <_Msg>[];

  bool _showEmoji = false;

  // welcome-inject (only when server history is empty)
  bool _welcomeInjected = false;
  void _maybeInsertWelcome() {
    if (_welcomeInjected) return;
    if (_messages.isEmpty) {
      _messages.add(_Msg(
        text: 'Hi! Welcome to Crypto Wallet Support 👋',
        fromAgent: true,
        ts: DateTime.now(),
      ));
      _welcomeInjected = true;
    }
  }

  // shimmer
  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  // lifecycle guard
  bool _isMounted = false;
  void _safeSetState(VoidCallback fn) {
    if (!mounted || !_isMounted) return;
    setState(fn);
  }

  void _safeAddMsg(_Msg m) {
    if (!mounted || !_isMounted) return;
    setState(() => _messages.add(m));
    _scrollToBottom();
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    _skeletonController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _skeletonAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );

    // clear unread when user opens the chat screen
    SupportChatBadge.instance.clear();

    _scroll.addListener(_handleScrollVisibilityCheck);

    _initSocket(); // authenticate first
  }

  @override
  void dispose() {
    _isMounted = false;
    _skeletonController.dispose();

    try {
      _socket?.off('authenticated');
      _socket?.off('auth-error');
      _socket?.off('chat-created');
      _socket?.off('message-sent');
      _socket?.off('message-received');
      _socket?.off('chat-history');
      _socket?.disconnect();
      _socket?.destroy();
    } catch (_) {}

    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ----------------- Socket.IO wiring -----------------

  Future<void> _initSocket() async {
    if (_connecting) return;
    _safeSetState(() {
      _connecting = true;
      _initializing = true;
    });

    try {
      _jwt = await AuthService.getStoredToken();
      if (_jwt == null || _jwt!.isEmpty) {
        _showSnack('Please login to start support chat.');
        _safeSetState(() {
          _connecting = false;
          _initializing = false;
        });
        return;
      }

      const url = 'https://vault-backend-cmjd.onrender.com';
      final socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .build(),
      );

      socket.off('authenticated');
      socket.off('auth-error');
      socket.off('chat-created');
      socket.off('message-sent');
      socket.off('message-received');
      socket.off('chat-history');

      // keep UI silent for connect/reconnect (no system bubbles)
      socket.onConnect((_) => _emitAuthenticate());
      socket.onReconnect((_) {});
      socket.onDisconnect((_) => _safeSetState(() {
            _authenticated = false;
            _initializing = true;
          }));
      socket.onConnectError((e) => _log('Connect error: $e'));
      socket.onError((e) => _log('Socket error: $e'));

      // AUTH OK
      socket.on('authenticated', (data) {
        _authenticated = true;
        final chatId = _extractChatId(data);
        if (chatId != null && chatId.isNotEmpty) {
          _chatId = chatId;
          _log('Authenticated with chatId: $_chatId'); // PRINT chatId
          _requestHistory();
        } else {
          _createChat();
        }
        _safeSetState(() {});
      });

      // AUTH FAIL
      socket.on('auth-error', (data) {
        _authenticated = false;
        _initializing = false;
        _showSnack('Support chat authentication failed.');
        _safeSetState(() {});
      });

      // CHAT CREATED
      socket.on('chat-created', (data) {
        try {
          final cid = (data?['chat']?['_id'] ?? '').toString();
          if (cid.isNotEmpty) {
            _chatId = cid;
            _log('chat-created -> chatId: $_chatId'); // PRINT chatId
            _requestHistory();

            // If history ends up empty, inject welcome locally
            _safeSetState(() {
              if (_messages.isEmpty) _maybeInsertWelcome();
            });
          }
        } catch (e) {
          _log('chat-created parse error: $e');
        }
      });

      // HISTORY
      socket.on('chat-history', (data) {
        _safeSetState(() {
          _loadingHistory = false;
          _initializing = false;
        });

        final rawList =
            (data is List) ? data : (data?['messages'] ?? data?['history']);
        if (rawList is! List) {
          _log('chat-history: unexpected payload: $data');
          return;
        }

        final parsed = <_Msg>[];
        for (final item in rawList) {
          try {
            final msgObj = _extractMessageObject(item);
            if (msgObj == null) continue;

            final content = (msgObj['content'] ?? '').toString();
            if (content.isEmpty) continue;

            final ts =
                DateTime.tryParse(msgObj['createdAt']?.toString() ?? '') ??
                    DateTime.now();

            final isAdmin = (msgObj['isAdminMessage'] == true) ||
                (msgObj['sender'] is Map &&
                    (msgObj['sender']['isAdmin'] == true));

            parsed.add(_Msg(
              text: content,
              fromAgent: isAdmin,
              ts: ts,
              sent: !isAdmin, // user's past msgs are "sent"
            ));
          } catch (e) {
            _log('chat-history item parse error: $e');
          }
        }

        parsed.sort((a, b) => a.ts.compareTo(b.ts));
        _safeSetState(() {
          _messages
            ..clear()
            ..addAll(parsed);

          // If server returned no messages, show a single local welcome
          if (_messages.isEmpty) {
            _maybeInsertWelcome();
          }
        });

        // Seeing history == user is on chat; clear unread
        SupportChatBadge.instance.clear();
        _scrollToBottom();
      });

      // CONFIRM SEND
      socket.on('message-sent', (data) {
        for (var i = _messages.length - 1; i >= 0; i--) {
          final m = _messages[i];
          if (!m.fromAgent && !m.sent) {
            _safeSetState(() => _messages[i] = m.copyWith(sent: true));
            break;
          }
        }
      });

      // LIVE INCOMING (ADMIN)
      socket.on('message-received', (data) {
        final msg = data?['message'];
        if (msg == null) return;

        final isAdmin = msg['isAdminMessage'] == true ||
            (msg['sender'] is Map && (msg['sender']['isAdmin'] == true));
        if (!isAdmin) return; // only admin messages affect the thread/badge

        final content = msg['content']?.toString() ?? '';
        if (content.isEmpty) return;

        final cid = msg['chat']?['_id']?.toString();
        if ((cid != null && cid.isNotEmpty) &&
            (_chatId == null || _chatId!.isEmpty)) {
          _chatId = cid;
          _log('message-received -> chatId learned: $_chatId'); // PRINT chatId
          _requestHistory();
        }

        final ts = DateTime.tryParse(msg['createdAt']?.toString() ?? '') ??
            DateTime.now();

        // If user isn't at bottom (message not visible yet), increment unread
        if (!_isAtBottom()) {
          SupportChatBadge.instance.increment();
        } else {
          SupportChatBadge.instance.clear();
        }

        _safeAddMsg(_Msg(text: content, fromAgent: true, ts: ts, sent: true));
      });

      _socket = socket;
      socket.connect();
    } catch (e) {
      _log('Init socket failed: $e');
      _safeSetState(() {
        _initializing = false;
      });
    } finally {
      _safeSetState(() => _connecting = false);
    }
  }

  void _emitAuthenticate() {
    if (_socket == null || _jwt == null) return;
    _socket!.emit('authenticate', {'token': _jwt});
  }

  void _createChat() {
    if (!_authenticated || _socket == null) return;
    _socket!.emit('create-chat', {});
  }

  void _requestHistory() {
    if (_socket == null || _chatId == null || _chatId!.isEmpty) return;
    _safeSetState(() => _loadingHistory = true);
    _socket!.emit('get-chat-history', {'chatId': _chatId});
  }

  String? _extractChatId(dynamic data) {
    try {
      final raw = data?['chatId'];
      if (raw is bool && raw == false) return null;
      final s = raw?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _extractMessageObject(dynamic item) {
    if (item is Map<String, dynamic>) {
      if (item['message'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(item['message'] as Map);
      }
      return item;
    }
    return null;
  }

  // ----------------- UI Actions -----------------

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
      if (result == null) return;

      final picked = result.files.map((f) {
        final ext = (f.extension ?? '').trim();
        final mime = guessMimeFromExtension(ext);
        return _Attachment(
          name: f.name,
          size: f.size,
          mimeType: mime,
          bytes: f.bytes,
          path: f.path,
        );
      }).toList();

      _safeSetState(() {
        _draftAttachments.addAll(picked);
      });
    } catch (e) {
      if (!mounted || !_isMounted) return;
      _showSnack('Attachment failed: $e');
    }
  }

  void _removeDraftAttachment(_Attachment a) {
    _safeSetState(() => _draftAttachments.remove(a));
  }

  void _send() {
    final text = _controller.text.trim();
    final hasText = text.isNotEmpty;
    final hasFiles = _draftAttachments.isNotEmpty;
    if (!hasText && !hasFiles) return;

    if (_initializing) {
      _showSnack('Please wait while connecting...');
      return;
    }
    if (!_authenticated || _socket == null) {
      _showSnack('Not connected yet.');
      return;
    }

    _ensureChatThen(() {
      if (hasText) {
        _safeAddMsg(_Msg(
          text: text,
          fromAgent: false,
          ts: DateTime.now(),
          sent: false, // will turn true on 'message-sent'
        ));
      }

      _socket!.emit('send-message', {
        'content': text,
        'chatId': _chatId,
      });

      _controller.clear();
      _safeSetState(() {
        _draftAttachments.clear();
        _showEmoji = false;
      });
    });
  }

  void _ensureChatThen(void Function() action) {
    if (_chatId != null && _chatId!.isNotEmpty) {
      action();
      return;
    }
    _createChat();
    _showSnack('Creating chat… please send again in a moment.');
  }

  // ----------------- Visibility / unread helpers -----------------

  bool _isAtBottom({double tolerance = 24}) {
    if (!_scroll.hasClients) return true;
    final max = _scroll.position.maxScrollExtent;
    final pix = _scroll.position.pixels;
    return (max - pix) <= tolerance;
  }

  void _handleScrollVisibilityCheck() {
    // As soon as the user reaches bottom, we mark all unread as seen
    if (_isAtBottom()) {
      SupportChatBadge.instance.clear();
    }
  }

  // ----------------- Misc helpers -----------------

  void _scrollToBottom() {
    if (!mounted || !_isMounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMounted) return;
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _log(String msg) {
    // single place to print logs
    // ignore: avoid_print
    print('[support-chat] $msg');
  }

  // ----------------- Skeleton UI -----------------

  late final _skeletonLineColor1 = Colors.white.withOpacity(0.1);
  late final _skeletonLineColor2 = Colors.white.withOpacity(0.2);

  Widget _buildSkeletonMessage({required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF4C5BEB).withOpacity(0.3)
                : const Color(0xFF171E2A).withOpacity(0.6),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildSkeletonLine(
                  width: MediaQuery.of(context).size.width * 0.6),
              const SizedBox(height: 6),
              _buildSkeletonLine(
                  width: MediaQuery.of(context).size.width * 0.4),
              const SizedBox(height: 8),
              _buildSkeletonLine(width: 60, height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLine({required double width, double height = 16}) {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        final stops = [
          _skeletonAnimation.value - 0.3,
          _skeletonAnimation.value,
          _skeletonAnimation.value + 0.3,
        ].map((s) => s.clamp(0.0, 1.0)).toList();

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: stops,
              colors: [
                _skeletonLineColor1,
                _skeletonLineColor2,
                _skeletonLineColor1
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeletons() {
    return Column(
      children: [
        _buildSkeletonMessage(isMe: false),
        _buildSkeletonMessage(isMe: true),
        _buildSkeletonMessage(isMe: false),
        _buildSkeletonMessage(isMe: true),
        _buildSkeletonMessage(isMe: false),
      ],
    );
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C1118);
    const bubbleMe = Color(0xFF4C5BEB);
    const bubbleAgent = Color(0xFF171E2A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          splashRadius: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Text(
              'Crypto Wallet Support',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            if (_initializing || _connecting || _loadingHistory)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_authenticated)
              const Icon(Icons.verified,
                  size: 18, color: Colors.lightGreenAccent)
            else
              const Icon(Icons.wifi_off, size: 18, color: Colors.orangeAccent),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages
            Expanded(
              child: _initializing
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      children: [_buildLoadingSkeletons()],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final isMe = !m.fromAgent;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? bubbleMe : bubbleAgent,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (m.text.isNotEmpty)
                                    Text(
                                      m.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.25,
                                      ),
                                    ),
                                  if (m.attachments.isNotEmpty)
                                    const SizedBox(height: 8),
                                  if (m.attachments.isNotEmpty)
                                    _MessageAttachmentsView(
                                      attachments: m.attachments,
                                      isMine: isMe,
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _timeOf(m.ts),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.65),
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        if (m.sent)
                                          Text(
                                            'sent',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.65),
                                              fontSize: 11,
                                            ),
                                          )
                                        else
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 10,
                                                height: 10,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.white
                                                        .withOpacity(0.65),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'sending…',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.65),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Emoji panel
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _EmojiPanel(onPick: (e) {
                final t = _controller.text;
                final sel = _controller.selection;
                final before = sel.start >= 0 ? t.substring(0, sel.start) : t;
                final after = sel.end >= 0 ? t.substring(sel.end) : '';
                final next = '$before$e$after';
                _controller.value = TextEditingValue(
                  text: next,
                  selection:
                      TextSelection.collapsed(offset: (before + e).length),
                );
              }),
              crossFadeState: _showEmoji
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),

            // Draft attachments preview row
            if (_draftAttachments.isNotEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1522),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.06)),
                    bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _draftAttachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final a = _draftAttachments[i];
                      final isImage = a.mimeType?.startsWith('image/') == true;
                      return Stack(
                        children: [
                          Container(
                            width: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFF121A29),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: isImage && a.bytes != null
                                      ? Image.memory(a.bytes!,
                                          fit: BoxFit.cover)
                                      : Icon(fileIconFor(a.mimeType),
                                          color: Colors.white70),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatBytes(a.size),
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => _removeDraftAttachment(a),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

            // Input bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E1522),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () {
                      _safeSetState(() => _showEmoji = !_showEmoji);
                      _scrollToBottom();
                    },
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Attach files',
                    onPressed: _pickAttachments,
                    icon: const Icon(Icons.attach_file, color: Colors.white70),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      onTap: () => _safeSetState(() => _showEmoji = false),
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: const Color(0xFF121A29),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.18)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      tooltip: 'Send',
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white),
                      splashRadius: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeOf(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final am = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }
}

// ----------------- Models & UI bits -----------------

class _Msg {
  final String text;
  final bool fromAgent;
  final DateTime ts;
  final bool sent; // only for user's messages
  final List<_Attachment> attachments;

  const _Msg({
    required this.text,
    required this.fromAgent,
    required this.ts,
    this.sent = true,
    this.attachments = const [],
  });

  _Msg copyWith({
    String? text,
    bool? fromAgent,
    DateTime? ts,
    bool? sent,
    List<_Attachment>? attachments,
  }) {
    return _Msg(
      text: text ?? this.text,
      fromAgent: fromAgent ?? this.fromAgent,
      ts: ts ?? this.ts,
      sent: sent ?? this.sent,
      attachments: attachments ?? this.attachments,
    );
  }
}

class _Attachment {
  final String name;
  final int size; // bytes
  final String? mimeType;
  final Uint8List? bytes;
  final String? path;

  const _Attachment({
    required this.name,
    required this.size,
    this.mimeType,
    this.bytes,
    this.path,
  });
}

class _MessageAttachmentsView extends StatelessWidget {
  const _MessageAttachmentsView({
    required this.attachments,
    required this.isMine,
  });

  final List<_Attachment> attachments;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: attachments.map((a) {
            final isImage = a.mimeType?.startsWith('image/') == true;
            return Container(
              width: isImage ? 150 : 180,
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: isImage && a.bytes != null
                  ? Image.memory(a.bytes!, fit: BoxFit.cover, height: 120)
                  : Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06)),
                          child: Icon(fileIconFor(a.mimeType),
                              color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                right: 8, top: 8, bottom: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatBytes(a.size),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ----------------- Small helpers -----------------

String? guessMimeFromExtension(String ext) {
  final e = ext.toLowerCase();
  switch (e) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'm4a':
      return 'audio/mp4';
    case 'pdf':
      return 'application/pdf';
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/x-rar-compressed';
    case '7z':
      return 'application/x-7z-compressed';
    case 'csv':
      return 'text/csv';
    case 'txt':
      return 'text/plain';
    case 'md':
      return 'text/markdown';
    case 'json':
      return 'application/json';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    default:
      return null;
  }
}

IconData fileIconFor(String? mime) {
  if (mime == null) return Icons.insert_drive_file_outlined;
  if (mime.startsWith('image/')) return Icons.image;
  if (mime.startsWith('video/')) return Icons.videocam;
  if (mime.startsWith('audio/')) return Icons.audiotrack;
  if (mime.contains('pdf')) return Icons.picture_as_pdf;
  if (mime.contains('zip') || mime.contains('compressed'))
    return Icons.archive_outlined;
  if (mime.contains('spreadsheet') || mime.contains('excel'))
    return Icons.grid_on;
  if (mime.contains('presentation') || mime.contains('powerpoint'))
    return Icons.slideshow;
  if (mime.contains('msword') || mime.contains('wordprocessing'))
    return Icons.description;
  if (mime.contains('text') || mime.contains('json') || mime.contains('csv'))
    return Icons.notes;
  return Icons.insert_drive_file_outlined;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final digits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
  return '${size.toStringAsFixed(digits)} ${units[unit]}';
}

/// Built-in emoji grid (no packages)
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onPick});
  final ValueChanged<String> onPick;

  static const _emojis = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😉',
    '😍',
    '😘',
    '😎',
    '🤩',
    '😇',
    '🙂',
    '🤔',
    '😴',
    '😌',
    '😢',
    '😭',
    '😤',
    '😅',
    '🙃',
    '👍',
    '👎',
    '🙏',
    '👏',
    '✌️',
    '🤝',
    '💪',
    '🔥',
    '✨',
    '💯',
    '🎉',
    '🥳',
    '💬',
    '🧡',
    '💜',
    '🔒',
    '🪙',
    '💸',
    '📈',
    '🆘',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1522),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _emojis.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemBuilder: (_, i) {
          final e = _emojis[i];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onPick(e),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF121A29),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              alignment: Alignment.center,
              child: Text(e, style: const TextStyle(fontSize: 20)),
            ),
          );
        },
      ),
    );
  }
}
