import 'dart:async';

import 'package:flutter/material.dart';

/// Membungkus layar dan memanggil [onIdle] setelah [timeout] tanpa aktivitas
/// pointer/keyboard. Dipakai untuk kembali ke layar utama secara otomatis.
class IdleWatcher extends StatefulWidget {
  const IdleWatcher({
    super.key,
    required this.child,
    required this.onIdle,
    this.timeout = const Duration(seconds: 90),
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onIdle;
  final Duration timeout;
  final bool enabled;

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant IdleWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout ||
        oldWidget.enabled != widget.enabled) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (!widget.enabled) return;
    _timer = Timer(widget.timeout, widget.onIdle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
