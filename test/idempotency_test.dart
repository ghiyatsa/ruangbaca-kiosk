import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ruangbaca_kiosk/api/api_exception.dart';
import 'package:ruangbaca_kiosk/api/idempotency.dart';
import 'package:ruangbaca_kiosk/api/kiosk_api.dart';
import 'package:ruangbaca_kiosk/core/app_config.dart';
import 'package:ruangbaca_kiosk/features/borrow/borrow_form.dart';
import 'package:ruangbaca_kiosk/state/kiosk_controller.dart';

const _config = AppConfig(
  baseUrl: 'https://contoh.test',
  apiKey: 'uji-api-key',
  deviceName: 'Kiosk Uji',
);

/// Membuktikan penanganan koneksi terputus pada transaksi tulis:
///
/// 1. `ApiException.isConnectionError` benar saat server tak terjangkau,
///    sehingga UI dapat membedakannya dari penolakan server.
/// 2. Percobaan ulang mengirim `Idempotency-Key` yang SAMA seperti percobaan
///    pertama — inilah yang mencegah pinjaman ganda ketika permintaan pertama
///    sebenarnya sudah diproses server tetapi responsnya hilang.
void main() {
  group('IdempotencyKey', () {
    test('key stabil selama basis tidak berubah', () {
      final key = IdempotencyKey();

      final first = key.forBasis('borrow|210170001|1,2');
      final retry = key.forBasis('borrow|210170001|1,2');

      expect(retry, first);
    });

    test('basis berbeda menghasilkan key baru', () {
      final key = IdempotencyKey();

      final first = key.forBasis('borrow|210170001|1');
      final other = key.forBasis('borrow|210170001|2');

      expect(other, isNot(first));
    });

    test('clear memulai transaksi berikutnya dengan key baru', () {
      final key = IdempotencyKey();

      final first = key.forBasis('borrow|210170001|1');
      key.clear();
      final next = key.forBasis('borrow|210170001|1');

      expect(next, isNot(first));
    });
  });

  group('pesan galat koneksi', () {
    test('menambahkan arahan coba-ulang hanya untuk galat koneksi', () {
      final connection = ApiException(
        'Koneksi terputus.',
        isConnectionError: true,
      );
      final validation = ApiException('Data tidak valid.', statusCode: 422);

      expect(
        transactionErrorMessage(connection, 'Peminjaman'),
        contains('tidak akan tercatat ganda'),
      );
      expect(
        transactionErrorMessage(validation, 'Peminjaman'),
        'Data tidak valid.',
      );
    });
  });

  testWidgets('percobaan ulang memakai Idempotency-Key yang sama', (
    tester,
  ) async {
    final borrowKeys = <String?>[];
    var borrowAttempts = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/api/kiosk/books/search')) {
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
            'suggestions': <String>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/api/kiosk/loans/borrow')) {
        borrowAttempts++;
        borrowKeys.add(request.headers['Idempotency-Key']);

        // Percobaan pertama: server tidak terjangkau.
        if (borrowAttempts == 1) {
          throw const SocketException('Koneksi ditolak');
        }

        return http.Response(
          jsonEncode({
            'loan': {
              'id': 555,
              'member': {'name': 'Ahmad Fauzi'},
              'books_count': 1,
              'borrowed_at': '2026-06-07T03:00:00+07:00',
              'due_at': '2026-06-14T03:00:00+07:00',
            },
            'message': 'Peminjaman berhasil.',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }

      // bootstrap & sisanya.
      return http.Response(
        jsonEncode({
          'loan_max_books': 3,
          'visitor_type_options': {'mahasiswa': 'Mahasiswa'},
          'purpose_options': {'read': 'Baca di tempat'},
          'session': {'timezone': 'Asia/Jakarta', 'withinOperatingHours': true},
          'stats': {'todayVisits': 0, 'todayBorrowed': 0, 'todayReturned': 0},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: _config,
      api: KioskApi(config: _config, client: client),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: BorrowForm(loanMaxBooks: 3)),
        ),
      ),
    );

    // Isi identitas anggota.
    await tester.enterText(find.byType(TextField), '210170001');
    await tester.pump();

    // Pilih buku lewat dialog pencarian.
    await tester.tap(find.text('Cari Buku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Algoritma dan Pemrograman'));
    await tester.pump();
    await tester.tap(find.text('Gunakan'));
    await tester.pumpAndSettle();

    // Percobaan pertama: scan QR lalu kirim -> gagal karena koneksi.
    //
    // Tidak memakai pumpAndSettle: selama pengiriman, tombol menampilkan
    // indikator putar yang tidak pernah "settle".
    Future<void> scanAndSubmit() async {
      await tester.tap(find.text('Lanjutkan Peminjaman'));
      await tester.pump(); // mulai kirim -> dialog verifikasi muncul
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).last, 'MK-payload-uji');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(); // dialog ditutup, permintaan dikirim
      await tester.pump(const Duration(milliseconds: 600));
    }

    await scanAndSubmit();

    expect(find.textContaining('tidak akan tercatat ganda'), findsOneWidget);

    // Percobaan ulang: scan QR baru (QR sekali pakai) lalu kirim -> sukses.
    await scanAndSubmit();

    expect(borrowAttempts, 2);
    expect(borrowKeys.first, isNotNull);
    expect(borrowKeys[1], borrowKeys.first);
    expect(find.text('Peminjaman Berhasil'), findsOneWidget);

    controller.dispose();
  });
}
