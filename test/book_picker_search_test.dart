import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ruangbaca_kiosk/api/kiosk_api.dart';
import 'package:ruangbaca_kiosk/core/app_config.dart';
import 'package:ruangbaca_kiosk/state/kiosk_controller.dart';
import 'package:ruangbaca_kiosk/widgets/book_picker_dialog.dart';

/// Membuktikan dialog pencarian buku di menu peminjaman memakai sistem
/// pencarian global: menampilkan saran kata kunci dan mengetuk saran
/// mengulang pencarian dengan kata kunci tersebut.
void main() {
  const config = AppConfig(
    baseUrl: 'https://contoh.test',
    apiKey: 'kunci-uji',
    deviceName: 'Kiosk Uji',
  );

  testWidgets('menampilkan saran dan mengetuknya mengulang pencarian', (
    tester,
  ) async {
    final queries = <String>[];

    final client = MockClient((request) async {
      final q = request.url.queryParameters['q'] ?? '';
      queries.add(q);

      return http.Response(
        jsonEncode({
          'books': [
            {
              'id': 1,
              'title': 'Metode Penelitian Kualitatif',
              'authors': [
                {'id': 3, 'name': 'Sugiyono'},
              ],
              'itemsCount': 2,
              'availableItemsCount': 1,
              'isbn': '9786021234567',
            },
          ],
          'suggestions': q == 'metde'
              ? ['metode penelitian kualitatif', 'metode']
              : <String>[],
          'corrected_query': q == 'metde' ? 'metode' : null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: config,
      api: KioskApi(config: config, client: client),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: BookPickerDialog(mode: 'borrow')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ketik kata kunci dengan salah eja.
    await tester.enterText(find.byType(TextField), 'metde');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Saran tampil dan indikator koreksi ejaan muncul.
    expect(find.text('metode penelitian kualitatif'), findsOneWidget);
    expect(find.textContaining('Menampilkan hasil untuk'), findsOneWidget);

    // Ketuk saran -> query berubah dan pencarian diulang.
    await tester.tap(find.text('metode penelitian kualitatif'));
    await tester.pumpAndSettle();

    expect(queries.last, 'metode penelitian kualitatif');

    controller.dispose();
  });
}
