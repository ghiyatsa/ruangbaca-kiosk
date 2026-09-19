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

/// Membuktikan dialog pencarian buku di menu peminjaman memakai pencarian
/// global (hasil berperingkat dari server) tanpa menampilkan saran kata kunci
/// maupun pemberitahuan koreksi ejaan — kiosk harus tetap sesederhana mungkin.
void main() {
  const config = AppConfig(
    baseUrl: 'https://contoh.test',
    apiKey: 'uji-api-key',
    deviceName: 'Kiosk Uji',
  );

  testWidgets('menampilkan hasil buku tanpa saran atau koreksi ejaan', (
    tester,
  ) async {
    final queries = <String>[];

    final client = MockClient((request) async {
      final q = request.url.queryParameters['q'] ?? '';
      queries.add(q);

      // Server tiruan tetap mengirim saran/koreksi (server lama), tetapi UI
      // kiosk harus mengabaikannya.
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
          'suggestions': ['metode penelitian kualitatif', 'metode'],
          'corrected_query': 'metode',
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

    // Hasil buku tampil...
    expect(find.text('Metode Penelitian Kualitatif'), findsOneWidget);

    // ...tetapi TIDAK ada chip saran maupun pemberitahuan koreksi ejaan.
    expect(find.byType(ActionChip), findsNothing);
    expect(find.textContaining('Menampilkan hasil untuk'), findsNothing);

    controller.dispose();
  });
}
