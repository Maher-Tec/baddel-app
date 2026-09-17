import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a small branded toast card floating above the app, replacing the
/// plain default [SnackBar] with something that matches Baddel's own look
/// (dark rounded card, teal "B" badge, matching the warning popup style).
void showBaddelToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  final removed = Completer<void>();

  void dismiss() {
    if (removed.isCompleted) return;
    removed.complete();
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _BaddelToastCard(
      message: message,
      icon: icon,
      duration: duration,
      onDismiss: dismiss,
    ),
  );
  overlay.insert(entry);
}

class _BaddelToastCard extends StatefulWidget {
  const _BaddelToastCard({
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_BaddelToastCard> createState() => _BaddelToastCardState();
}

class _BaddelToastCardState extends State<_BaddelToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _autoDismiss = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _autoDismiss?.cancel();
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12212B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF0D9488), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D9488),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.icon, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _dismiss,
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
