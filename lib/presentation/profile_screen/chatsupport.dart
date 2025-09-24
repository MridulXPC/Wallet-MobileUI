// lib/presentation/support/support_chat_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:cryptowallet/services/api_service.dart'; // <-- for JWT

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  // Socket/Chat state
  IO.Socket? _socket;
  bool _connecting = false;
  bool _authenticated = false;
  String? _chatId; // set after authenticate or create-chat
  String? _jwt; // cached JWT

  /// Draft attachments (selected but not sent yet)
  final List<_Attachment> _draftAttachments = <_Attachment>[];

  /// Messages: only a single admin welcome (no user dummy messages)
  final List<_Msg> _messages = <_Msg>[
    _Msg(
      text: 'Hi! Welcome to Crypto Wallet Support 👋',
      fromAgent: true,
      ts: DateTime.now(),
    ),
  ];

  bool _showEmoji = false;

  // ------- safety flags/helpers to avoid setState after dispose -------
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
    _initSocket(); // authenticate is the very first event
  }

  @override
  void dispose() {
    _isMounted = false;

    // Clean up socket listeners & connection
    try {
      _socket?.off('authenticated');
      _socket?.off('auth-error');
      _socket?.off('chat-created');
      _socket?.off('message-sent');
      _socket?.off('message-received');
      // _socket?.offConnect();
      // _socket?.offReconnect((_) {});
      // _socket?.offDisconnect((_) {});
      // _socket?.offConnectError((_) {});
      // _socket?.offError((_) {});
      _socket?.disconnect();
      _socket?.destroy();
      // (close()/dispose() may not exist on all versions; destroy() is enough)
    } catch (_) {}

    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ----------------- Socket.IO wiring -----------------

  Future<void> _initSocket() async {
    if (_connecting) return;
    _safeSetState(() => _connecting = true);

    try {
      _jwt = await AuthService.getStoredToken();
      if (_jwt == null || _jwt!.isEmpty) {
        _appendSystem('No token found. Please login first.');
        _safeSetState(() => _connecting = false);
        return;
      }

      final url = 'https://vault-backend-cmjd.onrender.com';
      final socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .build(),
      );

      // --- core connection events ---
      socket.onConnect((_) {
        _appendSystem('Connected. Authenticating…');
        _emitAuthenticate();
      });

      socket.onReconnect((_) => _appendSystem('Reconnected.'));
      socket.onDisconnect((_) {
        _safeSetState(() => _authenticated = false);
        _appendSystem('Disconnected.');
      });
      socket.onConnectError((e) => _appendSystem('Connect error: $e'));
      socket.onError((e) => _appendSystem('Socket error: $e'));

      // --- protocol events you provided ---
      socket.on('authenticated', (data) {
        _authenticated = true;
        final chatId = _extractChatId(data);
        _appendSystem('Authenticated.');
        if (chatId != null && chatId.isNotEmpty) {
          _chatId = chatId;
          _appendSystem('Resumed chat: $_chatId');
        } else {
          _createChat(); // no previous chat, create one
        }
        _safeSetState(() {});
      });

      socket.on('auth-error', (data) {
        _authenticated = false;
        _appendSystem('Auth error: $data');
        _safeSetState(() {});
      });

      socket.on('chat-created', (data) {
        try {
          final cid = (data?['chat']?['_id'] ?? '').toString();
          if (cid.isNotEmpty) {
            _chatId = cid;
            _appendSystem('Chat created: $_chatId');
            _safeSetState(() {});
          }
        } catch (_) {}
      });

      // Confirmation to sender
      socket.on('message-sent', (data) {
        final content = data?['content']?.toString() ?? '';
        if (content.isEmpty) return;
        _appendMy(content);
      });

      // Real-time message from agent (your backend sample said `message-received`;
      // payload used here assumes `message` key)
      socket.on('message-received', (data) {
        // Some servers send { content: "..."} — fallback to that if needed
        final content = (data?['message'] ?? data?['content'] ?? '').toString();
        if (content.isEmpty) return;
        _appendAgent(content);
      });

      _socket = socket;
      socket.connect();
    } catch (e) {
      _appendSystem('Init socket failed: $e');
    } finally {
      _safeSetState(() => _connecting = false);
    }
  }

  void _emitAuthenticate() {
    if (_socket == null || _jwt == null) return;
    _socket!.emit('authenticate', {
      'token': _jwt,
    });
  }

  void _createChat() {
    if (!_authenticated || _socket == null) return;
    _socket!.emit('create-chat', {});
  }

  // Ensures we have a chat before sending a message
  void _ensureChatThen(void Function() action) {
    if (_chatId != null && _chatId!.isNotEmpty) {
      action();
      return;
    }
    _createChat();
    _appendSystem('Creating chat… please try sending again.');
  }

  String? _extractChatId(dynamic data) {
    try {
      // success authenticated payload may contain: chatId: false || "id"
      final raw = data?['chatId'];
      if (raw is bool && raw == false) return null;
      final s = raw?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    } catch (_) {
      return null;
    }
  }

  // ----------------- UI Actions -----------------

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // bytes available (web-friendly)
        type: FileType.any, // any type
      );
      if (result == null) return;

      final picked = result.files.map((f) {
        final ext = (f.extension ?? '').trim();
        final mime = guessMimeFromExtension(ext);
        return _Attachment(
          name: f.name,
          size: f.size,
          mimeType: mime,
          bytes: f.bytes, // may be null on some platforms
          path: f.path, // null on web
        );
      }).toList();

      _safeSetState(() {
        _draftAttachments.addAll(picked);
      });
    } catch (e) {
      if (!mounted || !_isMounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attachment failed: $e')),
      );
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

    if (!_authenticated || _socket == null) {
      _appendSystem('Not connected yet. Please wait…');
      return;
    }

    _ensureChatThen(() {
      if (hasText) _appendMy(text);

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

  // ----------------- Helpers: messages & scroll -----------------

  void _appendSystem(String text) {
    _safeAddMsg(_Msg(text: text, fromAgent: true, ts: DateTime.now()));
  }

  void _appendMy(String text) {
    if (text.trim().isEmpty) return;
    _safeAddMsg(_Msg(text: text, fromAgent: false, ts: DateTime.now()));
  }

  void _appendAgent(String text) {
    if (text.trim().isEmpty) return;
    _safeAddMsg(_Msg(text: text, fromAgent: true, ts: DateTime.now()));
  }

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

  void _insertEmoji(String emoji) {
    final t = _controller.text;
    final sel = _controller.selection;
    final before = sel.start >= 0 ? t.substring(0, sel.start) : t;
    final after = sel.end >= 0 ? t.substring(sel.end) : '';
    final next = '$before$emoji$after';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + emoji).length),
    );
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0C1118);
    final bubbleMe = const Color(0xFF4C5BEB);
    final bubbleAgent = const Color(0xFF171E2A);

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
            if (_connecting)
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
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isMe = !m.fromAgent;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                            if (m.text.isNotEmpty) ...[
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
                            ],
                            if (m.attachments.isNotEmpty)
                              _MessageAttachmentsView(
                                attachments: m.attachments,
                                isMine: isMe,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _timeOf(m.ts),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11,
                              ),
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
              secondChild: _EmojiPanel(onPick: _insertEmoji),
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
                                      : Icon(
                                          fileIconFor(a.mimeType),
                                          color: Colors.white70,
                                        ),
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
  final List<_Attachment> attachments;

  const _Msg({
    required this.text,
    required this.fromAgent,
    required this.ts,
    this.attachments = const [],
  });
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
                            color: Colors.white.withOpacity(0.06),
                          ),
                          child: Icon(
                            fileIconFor(a.mimeType),
                            color: Colors.white70,
                          ),
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

// ----------------- Helpers -----------------

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
  if (mime.contains('zip') || mime.contains('compressed')) {
    return Icons.archive_outlined;
  }
  if (mime.contains('spreadsheet') || mime.contains('excel')) {
    return Icons.grid_on;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) {
    return Icons.slideshow;
  }
  if (mime.contains('msword') || mime.contains('wordprocessing')) {
    return Icons.description;
  }
  if (mime.contains('text') || mime.contains('json') || mime.contains('csv')) {
    return Icons.notes;
  }
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
  final digits = size >= 100
      ? 0
      : size >= 10
          ? 1
          : 2;
  return '${size.toStringAsFixed(digits)} ${units[unit]}';
}

/// Simple built-in emoji grid (no packages)
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
