import 'kiosk_menu.dart';

/// Aturan pintasan keyboard untuk memilih menu kiosk.
///
/// Menu dipilih dengan **Alt + angka 1–4**.
///
/// Angka polos (tanpa Alt) sengaja TIDAK dianggap pintasan. Kiosk ini banyak
/// memakai kolom isian — nomor identitas anggota, tahun terbit, jumlah buku —
/// sehingga mengetik "1"–"4" saat mengisi formulir tidak boleh berpindah menu.
///
/// Logika dipisah dari widget agar dapat diuji tanpa membangun UI.
class KioskShortcut {
  const KioskShortcut._();

  /// Label tombol pengubah yang ditampilkan ke pengguna.
  static const String modifierLabel = 'Alt';

  /// Pola digit di akhir label tombol, agar `1` (baris angka) maupun
  /// `Numpad 1` (keypad) sama-sama dikenali.
  static final RegExp _trailingDigit = RegExp(r'(\d)$');

  /// Menentukan menu dari sebuah penekanan tombol.
  ///
  /// Mengembalikan `null` bila kombinasi bukan pintasan menu.
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
