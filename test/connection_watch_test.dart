import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ruangbaca_kiosk/api/kiosk_api.dart';
import 'package:ruangbaca_kiosk/app.dart';
import 'package:ruangbaca_kiosk/core/app_config.dart';
import 'package:ruangbaca_kiosk/features/borrow/borrow_form.dart';
import 'package:ruangbaca_kiosk/state/kiosk_controller.dart';
import 'package:ruangbaca_kiosk/widgets/feedback.dart';

const _config = AppConfig(
  baseUrl: 'https://contoh.test',
  apiKey: 'kunci-uji',
  deviceName: 'Kiosk Uji',
);

String _bootstrapBody() => jsonEncode({
  'loan_max_books': 3,
  'visitor_type_options': {'mahasiswa': 'Mahasiswa'},
  'purpose_options': {'read': 'Baca di tempat'},
  'session': {'timezone': 'Asia/Jakarta', 'withinOperatingHours': true},
  'stats': {'todayVisits': 0, 'todayBorrowed': 0, 'todayReturned': 0},
});

/// Membuktikan deteksi koneksi saat kiosk menganggur:
///
/// 1. Selama server terjangkau, tidak ada banner apa pun.
/// 2. Begitu server tidak terjangkau, `isOffline` benar dan banner peringatan
///    muncul — tanpa perlu menekan aksi apa pun.
/// 3. Saat koneksi pulih, banner hilang sendiri.
void main() {
  setUpAll(() async {
    // `AttractScreen` memformat tanggal Indonesia; data locale harus dimuat
    // lebih dulu (di aplikasi nyata dilakukan `main.dart`).
    await initializeDateFormatting('id_ID');
  });

  /// Resolusi layar kiosk yang sebenarnya (1536x960). Viewport uji bawaan
  /// (800x600) terlalu kecil dan memicu overflow layout yang tidak
  /// berhubungan dengan uji; memakai ukuran asli sekaligus membuktikan banner
  /// offline tidak membuat tata letak meluber di mesin nyata.
  void useKioskViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1536, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('banner muncul saat koneksi putus dan hilang saat pulih', (
    tester,
  ) async {
    useKioskViewport(tester);
    var reachable = true;

    final client = MockClient((request) async {
      if (!reachable) {
        throw const SocketException('Koneksi ditolak');
      }
      return http.Response(
        _bootstrapBody(),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: _config,
      api: KioskApi(config: _config, client: client),
      connectionCheckInterval: const Duration(milliseconds: 200),
    );

    await controller.initialize();
    await tester.pumpWidget(KioskApp(controller: controller));
    await tester.pump();

    // Awalnya online: banner tidak tampil.
    expect(controller.isOffline, isFalse);
    expect(find.byType(OfflineBanner), findsNothing);

    // Koneksi putus. Pantauan berkala harus menemukannya sendiri.
    reachable = false;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(controller.isOffline, isTrue);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Koneksi ke server terputus'), findsOneWidget);

    // Koneksi pulih: banner hilang tanpa interaksi pengguna.
    reachable = true;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(controller.isOffline, isFalse);
    expect(find.byType(OfflineBanner), findsNothing);

    controller.dispose();
  });

  test('pemeriksaan koneksi tidak menumpuk saat jaringan lambat', () async {
    // Server menggantung melebihi jeda timer. Hanya satu pemeriksaan yang
    // boleh berjalan; sisanya harus dilewati agar server tidak dibanjiri.
    var concurrent = 0;
    var maxConcurrent = 0;

    final client = MockClient((request) async {
      concurrent++;
      maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      concurrent--;
      return http.Response(
        _bootstrapBody(),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: _config,
      api: KioskApi(config: _config, client: client),
      connectionCheckInterval: const Duration(milliseconds: 10),
    );

    controller.startConnectionWatch();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    controller.stopConnectionWatch();

    expect(maxConcurrent, 1);

    controller.dispose();
  });

  test('galat non-jaringan tidak dianggap offline', () async {
    // Server menjawab 401: kredensial salah, bukan koneksi putus. Kiosk harus
    // tetap dianggap online agar banner tidak menyesatkan.
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'Tidak terautentikasi.'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: _config,
      api: KioskApi(config: _config, client: client),
    );

    await controller.checkConnection();

    expect(controller.isOffline, isFalse);

    controller.dispose();
  });

  testWidgets('tombol aksi dinonaktifkan saat offline', (tester) async {
    useKioskViewport(tester);
    var reachable = true;

    final client = MockClient((request) async {
      if (!reachable) {
        throw const SocketException('Koneksi ditolak');
      }
      if (request.url.path.endsWith('/api/kiosk/books/search')) {
        return http.Response(
          jsonEncode({
            'books': [
              {
                'id': 7,
                'title': 'Algoritma dan Pemrograman',
                'authors': [
                  {'id': 1, 'name': 'Rinaldi Munir'},
                ],
                'itemsCount': 2,
                'availableItemsCount': 2,
                'isbn': '9786021516036',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _bootstrapBody(),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    // Jeda panjang: pantauan otomatis tidak ikut campur, offline dipicu manual
    // lewat `checkConnection()` agar hasilnya deterministik.
    final controller = KioskController(
      config: _config,
      api: KioskApi(config: _config, client: client),
      connectionCheckInterval: const Duration(hours: 1),
    );

    await controller.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: BorrowForm(loanMaxBooks: 3)),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '210170001');
    await tester.pump();

    await tester.tap(find.text('Cari Buku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Algoritma dan Pemrograman'));
    await tester.pump();
    await tester.tap(find.text('Gunakan'));
    await tester.pumpAndSettle();

    FilledButton submit() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lanjutkan Peminjaman'),
    );

    // Form lengkap dan online: tombol aktif.
    expect(submit().onPressed, isNotNull);

    // Koneksi putus: tombol harus nonaktif walau form sudah lengkap.
    reachable = false;
    await controller.checkConnection();
    await tester.pump();

    expect(controller.isOffline, isTrue);
    expect(submit().onPressed, isNull);

    // Koneksi pulih: tombol aktif lagi.
    reachable = true;
    await controller.checkConnection();
    await tester.pump();

    expect(submit().onPressed, isNotNull);

    controller.dispose();
  });
}
