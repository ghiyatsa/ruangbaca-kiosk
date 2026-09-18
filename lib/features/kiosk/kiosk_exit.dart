import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme.dart';

/// Kunci navigasi global, dipakai agar dialog keluar dapat ditampilkan dari
/// luar pohon widget (mis. dari callback `onWindowClose`).
final GlobalKey<NavigatorState> kioskNavigatorKey = GlobalKey<NavigatorState>();

/// Frasa yang harus diketik pengguna untuk benar-benar keluar dari kiosk.
///
/// Ini bukan rahasia — tujuannya mencegah keluar karena sentuhan/klik tak
/// sengaja pada mesin yang dipakai umum, bukan melindungi dari orang yang
/// memang ingin keluar. Karena itu frasa ini boleh tampil di dokumentasi.
const String kioskExitPhrase = 'KELUAR';

/// Lama menekan logo di panel menu untuk membuka dialog keluar.
const Duration kioskExitLongPress = Duration(seconds: 3);

/// Menjaga jendela kiosk tetap terbuka dan menyediakan satu-satunya jalan
/// keluar yang disengaja.
///
/// Sebelumnya mode kiosk hanya memasang layar penuh dan selalu-di-atas,
/// sehingga tombol tutup jendela (X) dan Alt+F4 **langsung mematikan
/// aplikasi** — satu klik tak sengaja membuat kiosk mati. `setPreventClose`
/// memang belum pernah dipanggil meskipun komentar konfigurasi mengklaim
/// "cegah tombol tutup".
class KioskExitGuard with WindowListener {
  KioskExitGuard();

  bool _enabled = false;
  bool _promptOpen = false;

  /// Apakah penjagaan sedang aktif (mode kiosk menyala).
  bool get isEnabled => _enabled;

  /// Pasang penjagaan: jendela tidak dapat ditutup kecuali lewat [prompt].
  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  /// Lepas penjagaan (dipakai tepat sebelum aplikasi benar-benar keluar).
  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
  }

  /// Dipanggil saat sistem meminta jendela ditutup: klik X, Alt+F4, atau
  /// permintaan dari luar. Karena `setPreventClose(true)`, jendela TIDAK
  /// tertutup dengan sendirinya — di sini kita tawarkan konfirmasi.
  @override
  void onWindowClose() {
    if (!_enabled) return;
    unawaited(prompt());
  }

  /// Menampilkan dialog konfirmasi keluar.
  ///
  /// Aman dipanggil berkali-kali: permintaan saat dialog sudah terbuka
  /// diabaikan, sehingga menekan Alt+F4 berulang tidak menumpuk dialog.
  Future<void> prompt() async {
    if (!_enabled || _promptOpen) return;

    final context = kioskNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _promptOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const KioskExitDialog(),
      );

      if (confirmed == true) {
        // Lepas penjagaan lebih dulu, jika tidak jendela akan menolak ditutup.
        await disable();
        await windowManager.destroy();
      }
    } finally {
      _promptOpen = false;
    }
  }
}

/// Instance global penjaga keluar.
///
/// Dibuat global agar dapat dipanggil dari `main.dart` (saat menyiapkan
/// jendela) maupun dari UI (tekan lama logo), tanpa perlu meneruskan objek
/// melalui pohon widget.
final KioskExitGuard kioskExitGuard = KioskExitGuard();

/// Dialog konfirmasi keluar dari mode kiosk.
///
/// Keluar baru diizinkan setelah pengguna mengetik [kioskExitPhrase], sehingga
/// klik/sentuhan tak sengaja tidak dapat mematikan kiosk.
class KioskExitDialog extends StatefulWidget {
  const KioskExitDialog({super.key});

  @override
  State<KioskExitDialog> createState() => _KioskExitDialogState();
}

class _KioskExitDialogState extends State<KioskExitDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim().toUpperCase() == kioskExitPhrase;
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: KioskTheme.warning,
            size: 26,
          ),
          SizedBox(width: 10),
          Text('Keluar dari mode kiosk?', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi akan tertutup dan layanan mandiri tidak lagi tersedia '
              'sampai kiosk dijalankan kembali.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Text(
              'Ketik "$kioskExitPhrase" untuk mengonfirmasi.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E2233),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: kioskExitPhrase,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (value) {
                if (_matches) Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          // Tombol tidak aktif sampai frasa diketik dengan benar.
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Keluar'),
        ),
      ],
    );
  }
}
