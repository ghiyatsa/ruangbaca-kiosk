import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/theme.dart';
import 'features/kiosk/kiosk_exit.dart';
import 'features/startup/startup_error_screen.dart';
import 'features/kiosk/kiosk_shell.dart';
import 'state/kiosk_controller.dart';
import 'widgets/feedback.dart';

/// Akar aplikasi kiosk.
class KioskApp extends StatelessWidget {
  const KioskApp({super.key, required this.controller});

  final KioskController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<KioskController>.value(
      value: controller,
      child: MaterialApp(
        // Kunci navigator dipakai dialog keluar yang dipicu dari luar pohon
        // widget (callback onWindowClose pada KioskExitGuard).
        navigatorKey: kioskNavigatorKey,
        title: 'Kiosk ${Brand.shortName}',
        debugShowCheckedModeBanner: false,
        theme: KioskTheme.light(),
        home: const _KioskRoot(),
      ),
    );
  }
}

class _KioskRoot extends StatelessWidget {
  const _KioskRoot();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner koneksi selalu di atas layar, terlihat dari layanan
              // mana pun; hanya muncul saat kiosk offline.
              if (controller.isOffline) ...[
                const OfflineBanner(),
                const SizedBox(height: 16),
              ],
              Expanded(child: _body(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(KioskController controller) {
    switch (controller.status) {
      case KioskStatus.initializing:
        return const Center(child: CircularProgressIndicator());
      case KioskStatus.error:
        return StartupErrorScreen(
          message: controller.startupError ?? 'Terjadi kesalahan tak terduga.',
          onRetry: controller.initialize,
        );
      case KioskStatus.ready:
        return const KioskShell();
    }
  }
}
