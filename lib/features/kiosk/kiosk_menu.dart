import 'package:flutter/material.dart';

import 'kiosk_shortcut.dart';

/// Menu layanan kiosk — selaras dengan `resources/js/features/kiosk/menu.ts`.
///
/// Catatan: nilai `return` tidak dipakai karena merupakan kata kunci Dart,
/// sehingga dipakai `returnBook`.
enum KioskMenu {
  visit,
  member,
  borrow,
  returnBook;

  String get label {
    switch (this) {
      case KioskMenu.visit:
        return 'Buku Tamu';
      case KioskMenu.member:
        return 'Daftar Anggota';
      case KioskMenu.borrow:
        return 'Pinjam Buku';
      case KioskMenu.returnBook:
        return 'Kembalikan Buku';
    }
  }

  String get description {
    switch (this) {
      case KioskMenu.visit:
        return 'Catat kunjungan';
      case KioskMenu.member:
        return 'Pendaftaran anggota baru';
      case KioskMenu.borrow:
        return 'Peminjaman mandiri';
      case KioskMenu.returnBook:
        return 'Pengembalian buku';
    }
  }

  String get helper {
    switch (this) {
      case KioskMenu.visit:
        return 'Isi data singkat untuk mencatat kehadiran Anda di Ruang Baca.';
      case KioskMenu.member:
        return 'Lengkapi data identitas, lalu tautkan dengan akun Google Anda.';
      case KioskMenu.borrow:
        return 'Masukkan identitas anggota, pilih buku fisik, lalu konfirmasi '
            'dengan scan Member Key di HP.';
      case KioskMenu.returnBook:
        return 'Masukkan identitas anggota, pilih buku yang dikembalikan, '
            'lalu konfirmasi dengan scan Member Key di HP.';
    }
  }

  IconData get icon {
    switch (this) {
      case KioskMenu.visit:
        return Icons.assignment_outlined;
      case KioskMenu.member:
        return Icons.person_add_alt_1_outlined;
      case KioskMenu.borrow:
        return Icons.book_outlined;
      case KioskMenu.returnBook:
        return Icons.assignment_return_outlined;
    }
  }

  /// Digit pintasan menu: 1–4.
  ///
  /// Digit ini hanya berlaku bersama tombol **Alt** (lihat `KioskShortcut`),
  /// agar mengetik angka pada kolom isian tidak berpindah menu.
  String get shortcutKey => (index + 1).toString();

  /// Label pintasan untuk ditampilkan ke pengguna, mis. `Alt+1`.
  String get shortcutLabel => '${KioskShortcut.modifierLabel}+$shortcutKey';

  static KioskMenu? fromShortcut(String key) {
    switch (key) {
      case '1':
        return KioskMenu.visit;
      case '2':
        return KioskMenu.member;
      case '3':
        return KioskMenu.borrow;
      case '4':
        return KioskMenu.returnBook;
      default:
        return null;
    }
  }
}
