import 'package:uuid/uuid.dart';

import 'api_exception.dart';

/// Pesan galat transaksi tulis.
///
/// Saat koneksi terputus, hasil transaksi belum pasti (server bisa saja sudah
/// memprosesnya). Karena percobaan ulang memakai key yang sama — lihat
/// [IdempotencyKey] — mencoba lagi aman dan tidak menghasilkan transaksi
/// ganda, jadi hal itu perlu diberitahukan kepada pengguna.
String transactionErrorMessage(ApiException error, String actionLabel) {
  if (!error.isConnectionError) {
    return error.bestMessage;
  }

  return '${error.bestMessage} $actionLabel belum dapat dipastikan tersimpan. '
      'Tekan tombol sekali lagi untuk mencoba ulang dengan aman — '
      'permintaan tidak akan tercatat ganda.';
}

/// Menjaga satu `Idempotency-Key` untuk satu maksud transaksi tulis.
///
/// Percobaan ulang setelah kegagalan koneksi WAJIB memakai key yang sama:
/// server bisa saja sudah memproses permintaan pertama sebelum responsnya
/// hilang. Key baru pada percobaan ulang akan membuat server menganggapnya
/// transaksi berbeda dan memprosesnya lagi (mis. pinjaman ganda).
///
/// Key hanya diperbarui bila maksud transaksi berubah (basis berbeda) atau
/// setelah transaksi selesai. Basis harus memuat bidang yang juga dihitung
/// server pada sidik jarinya (identitas anggota + daftar buku).
class IdempotencyKey {
  IdempotencyKey({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  String? _key;
  String? _basis;

  /// Key stabil untuk [basis] yang sama; basis berbeda memulai transaksi baru.
  String forBasis(String basis) {
    if (_key == null || _basis != basis) {
      _key = _uuid.v4();
      _basis = basis;
    }

    return _key!;
  }

  /// Buang key aktif; panggil setelah transaksi berhasil.
  void clear() {
    _key = null;
    _basis = null;
  }
}
