import 'package:flutter/material.dart';

/// Menjalankan aksi async dengan indikator loading dan penanganan galat,
/// untuk menyederhanakan pola "tombol memproses" di seluruh form.
class AsyncRunner {
  const AsyncRunner._();

  /// Jalankan [action]; kembalikan `true` bila berhasil.
  ///
  /// [onSuccess] dipanggil saat berhasil, [onError] menerima pesan galat.
  static Future<bool> run({
    required Future<void> Function() action,
    void Function()? onSuccess,
    void Function(String message)? onError,
  }) async {
    try {
      await action();
      onSuccess?.call();
      return true;
    } catch (error) {
      onError?.call(_messageFor(error));
      return false;
    }
  }

  static String _messageFor(Object error) {
    // ApiException punya `bestMessage`; hindari impor siklus dengan duck typing.
    try {
      final dynamic dynamicError = error;
      final best = dynamicError.bestMessage;
      if (best is String && best.isNotEmpty) return best;
    } catch (_) {
      // Lanjut ke fallback.
    }
    return error.toString();
  }
}

/// Banner pesan (sukses / galat / info) untuk form kiosk.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.error,
    this.title,
  });

  final String message;
  final StatusTone tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (background, border, iconColor, icon) = switch (tone) {
      StatusTone.success => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        const Color(0xFF15803D),
        Icons.check_circle_outline,
      ),
      StatusTone.info => (
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
        const Color(0xFF1D4ED8),
        Icons.info_outline,
      ),
      StatusTone.warning => (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFFB45309),
        Icons.warning_amber_outlined,
      ),
      StatusTone.error => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        const Color(0xFFB91C1C),
        Icons.error_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { success, info, warning, error }
