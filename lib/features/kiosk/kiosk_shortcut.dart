import 'kiosk_menu.dart';

/// Aturan pintasan keyboard untuk memilih menu kiosk: Alt + angka 1-4.
///
/// Angka polos (tanpa Alt) bukan pintasan. Kiosk banyak memakai kolom isian
/// (nomor identitas, tahun terbit, jumlah buku), sehingga mengetik "1"-"4"
/// saat mengisi formulir tidak boleh berpindah menu.
///
/// Dipisah dari widget agar bisa diuji tanpa membangun UI.
class KioskShortcut {
  const KioskShortcut._();

  /// Label tombol pengubah yang ditampilkan ke pengguna.
  static const String modifierLabel = 'Alt';

  /// Digit di akhir label tombol, agar `1` di baris angka dan `Numpad 1`
  /// sama-sama dikenali.
  static final RegExp _trailingDigit = RegExp(r'(\d)$');

  /// Menu untuk sebuah penekanan tombol, atau `null` bila bukan pintasan.
  static KioskMenu? resolve({
    required String keyLabel,
    required bool altPressed,
    required bool ctrlPressed,
    required bool metaPressed,
    required bool shiftPressed,
  }) {
    // Hanya Alt murni. Ctrl (termasuk AltGr), Win, dan Shift+Alt tidak dipakai
    // agar tidak bentrok dengan pintasan sistem atau pengetikan normal.
    if (!altPressed || ctrlPressed || metaPressed || shiftPressed) {
      return null;
    }

    final match = _trailingDigit.firstMatch(keyLabel);
    if (match == null) {
      return null;
    }

    return KioskMenu.fromShortcut(match.group(1)!);
  }
}
