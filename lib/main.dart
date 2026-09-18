import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'features/kiosk/kiosk_exit.dart';
import 'state/kiosk_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID');

  final config = await AppConfig.load();

  if (config.kioskMode) {
    await _setupKioskWindow();
  }

  final controller = KioskController(config: config);
  unawaited(controller.initialize());

  runApp(KioskApp(controller: controller));
}

/// Konfigurasi jendela mode kiosk: layar penuh, selalu di atas, dan menahan
/// tombol tutup jendela.
///
/// Penahanan tombol tutup wajib dipasang di sini (bukan di dalam widget),
/// karena `windowManager` sudah siap sebelum UI dibangun — sehingga klik X
/// atau Alt+F4 pada saat mana pun tidak langsung mematikan aplikasi.
Future<void> _setupKioskWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 720),
    center: true,
    title: 'Kiosk Ruang Baca',
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
  });

  // Jendela menolak ditutup sampai guard melepasnya lewat dialog keluar.
  await kioskExitGuard.enable();
}
