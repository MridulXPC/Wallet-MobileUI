import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class TxFailureCard extends StatefulWidget {
  final String title;
  final String message;
  final String? txId; // optional: show short ref
  final VoidCallback? onRetry; // optional: retry handler
  final Duration autoHideAfter; // default 4s
  final bool barrier; // if true, show a faint dim/blur
  final VoidCallback? _onRemove; // injected by show()

  const TxFailureCard({
    super.key,
    required this.title,
    required this.message,
    this.txId,
    this.onRetry,
    this.autoHideAfter = const Duration(seconds: 4),
    this.barrier = false,
  }) : _onRemove = null;

  const TxFailureCard._internal({
    required this.title,
    required this.message,
    this.txId,
    this.onRetry,
    this.autoHideAfter = const Duration(seconds: 4),
    this.barrier = false,
    required VoidCallback onRemove,
  }) : _onRemove = onRemove;

  // --- one-liner to show the card (centered) ---
  static Future<void> show(
    BuildContext context, {
    String title = 'Transaction failed',
    required String message,
    String? txId,
    VoidCallback? onRetry,
    Duration autoHideAfter = const Duration(seconds: 40),
    bool barrier = false,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NonModalOverlay(
        barrier: barrier,
        child: TxFailureCard._internal(
          title: title,
          message: message,
          txId: txId,
          onRetry: onRetry,
          autoHideAfter: autoHideAfter,
          barrier: barrier,
          onRemove: () => entry.remove(),
        ),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<TxFailureCard> createState() => _TxFailureCardState();
}

class _TxFailureCardState extends State<TxFailureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_ac);
    _scale = Tween<double>(begin: 0.94, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_ac);

    _ac.forward();

    // auto-hide (kept off if Retry is present)
    if (widget.autoHideAfter > Duration.zero && widget.onRetry == null) {
      Future.delayed(widget.autoHideAfter, _dismiss);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    await _ac.reverse();
    widget._onRemove?.call(); // remove overlay entry
  }

  @override
  Widget build(BuildContext context) {
    // Card theme (matches your dark UI)
    const accent = Color(0xFFEF6727);

    final card = FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            color: Colors.transparent,
            child: Container(
              // keep it centered and comfortably sized on phones & tablets
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.of(context).size.height * 0.2,
                // ensure it never goes full screen even on tablets
                // and also never smaller than 280 so layout stays stable
                minWidth: 280,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF171B2B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2D3A), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title + close
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _dismiss,
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.close,
                                    color: Colors.white70, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                        ),
                        if (widget.txId != null && widget.txId!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Ref: ${_short(widget.txId!)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _dismiss,
                              child: const Text('Dismiss'),
                            ),
                            const SizedBox(width: 8),
                            if (widget.onRetry != null)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  widget.onRetry?.call();
                                  _dismiss();
                                },
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Centered overlay; taps outside pass through (non-modal)
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.barrier)
          IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: Container(color: const Color(0x55000000)),
              ),
            ),
          ),
        // Only the card itself captures taps; outside passes through.
        IgnorePointer(
          ignoring: false,
          child: SafeArea(
            child: Center(child: card),
          ),
        ),
      ],
    );
  }

  static String _short(String s) =>
      s.length <= 12 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
}

// Non-modal container that keeps touches passing through outside the card.
class _NonModalOverlay extends StatelessWidget {
  final Widget child;
  final bool barrier;
  const _NonModalOverlay({required this.child, required this.barrier});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(ignoring: false, child: child);
  }
}
