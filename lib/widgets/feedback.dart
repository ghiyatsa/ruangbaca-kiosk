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

/// Banner peringatan saat kiosk kehilangan koneksi ke server.
///
/// Ditampilkan persisten di atas layar selama kiosk offline; sengaja memakai
/// nada peringatan (bukan galat) karena kondisi ini biasanya sementara dan
/// pulih sendiri begitu jaringan kembali.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.checking = false});

  /// Benar bila pemeriksaan koneksi sedang berjalan.
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFB45309),
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koneksi ke server terputus',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Layanan sementara tidak dapat digunakan. Kiosk akan aktif '
                  'kembali sendiri begitu jaringan pulih.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (checking) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
