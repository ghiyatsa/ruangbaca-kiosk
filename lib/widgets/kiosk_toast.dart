import 'dart:async';

import 'package:flutter/material.dart';

/// Nada (tone) notifikasi kiosk.
enum KioskToastTone { success, info, warning, error }

/// Notifikasi ringan (toast) yang **menutup sendiri**.
///
/// Dipakai sebagai pengganti dialog sukses: setelah aksi berhasil (pinjam,
/// kembali, kunjungan), pengguna tidak perlu menekan tombol "Selesai" — toast
/// hilang otomatis setelah [duration]. Ini meniru `toast.success` pada kiosk
/// web (`sonner`), sehingga alur kiosk tetap mengalir tanpa klik tambahan.
///
/// Toast tidak menangkap sentuhan (`IgnorePointer`) agar tidak pernah
/// menghalangi kolom isian atau tombol di belakangnya.
class KioskToast {
  const KioskToast._();

  /// Durasi tampil bawaan.
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Toast yang sedang tampil, agar toast baru menggantikan yang lama
  /// alih-alih menumpuk.
  static OverlayEntry? _current;

  /// Tampilkan toast. Tidak melakukan apa pun bila [context] sudah tidak
  /// terpasang pada overlay.
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    String? detail,
    KioskToastTone tone = KioskToastTone.success,
    Duration duration = defaultDuration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _current?.remove();
    _current = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _KioskToastView(
        title: title,
        message: message,
        detail: detail,
        tone: tone,
        duration: duration,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (identical(_current, entry)) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  /// Tutup toast yang sedang tampil (mis. saat kembali ke layar utama).
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _KioskToastView extends StatefulWidget {
  const _KioskToastView({
    required this.title,
    required this.tone,
    required this.duration,
    required this.onDismissed,
    this.message,
    this.detail,
  });

  final String title;
  final String? message;
  final String? detail;
  final KioskToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_KioskToastView> createState() => _KioskToastViewState();
}

class _KioskToastViewState extends State<_KioskToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    _timer = null;

    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (accent, background, border, icon) = switch (widget.tone) {
      KioskToastTone.success => (
        const Color(0xFF15803D),
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        Icons.check_circle,
      ),
      KioskToastTone.info => (
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
        Icons.info,
      ),
      KioskToastTone.warning => (
        const Color(0xFFB45309),
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        Icons.warning_amber_rounded,
      ),
      KioskToastTone.error => (
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        Icons.error,
      ),
    };

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.35),
                  end: Offset.zero,
                ).animate(curve),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: accent, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                if (widget.message != null &&
                                    widget.message!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.message!,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ],
                                if (widget.detail != null &&
                                    widget.detail!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.detail!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E2233),
                                    ),
                                  ),
                                ],
                              ],
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
