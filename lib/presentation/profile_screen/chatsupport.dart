// support_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    required this.baseUrll, // e.g. "https://support.yourdomain.com" or "http://192.168.1.20:3000"
    required this.websiteToken, // from Chatwoot → Inboxes → Website → Configuration
    required this.userId,
  });

  final String baseUrll;
  final String websiteToken;
  final String userId;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  late final WebViewController _ctrl;
  double _progress = 0;

  String get _sdkUrl {
    final url = widget.baseUrll.endsWith('/')
        ? '${widget.baseUrll}packs/js/sdk.js'
        : '${widget.baseUrll}/packs/js/sdk.js';
    return url;
  }

  String _htmlSkeleton() => '''
<!doctype html><html><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Support</title>
</head><body style="margin:0;background:#fff;"></body></html>
''';

  String _injectJs() {
    // minimal escape
    String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    return """
      (function(){
        try {
          window.chatwootSettings = { hideMessageBubble:false, locale:'en', type:'standard' };
          var s = document.createElement('script');
          s.src = '${esc(_sdkUrl)}';
          s.async = true; s.defer = true;
          s.onload = function(){
            try{
              window.chatwootSDK.run({ websiteToken: '${esc(widget.websiteToken)}', baseUrl: '${esc(widget.baseUrll)}' });
              if (window.\$chatwoot && window.\$chatwoot.setUser) {
                window.\$chatwoot.setUser('${esc(widget.userId)}', {
                
                  app_version: '1.0.0'
                });
              }
              setTimeout(function(){ try{ window.\$chatwoot.toggle('open'); }catch(_){} }, 300);
            }catch(e){ console.error('Chatwoot run error', e); }
          };
          s.onerror = function(){ console.error('Failed to load SDK: ${esc(_sdkUrl)}'); };
          document.head.appendChild(s);
        } catch(e) { console.error('Inject error', e); }
      })();
    """;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: (_) async => _ctrl.runJavaScript(_injectJs()),
          onWebResourceError: (e) => debugPrint(
              'WebView resource error: ${e.errorCode} ${e.description}'),
        ),
      )
      ..loadHtmlString(_htmlSkeleton());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open Ticket')),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_progress < 1)
            LinearProgressIndicator(value: _progress, minHeight: 2),
        ],
      ),
    );
  }
}
