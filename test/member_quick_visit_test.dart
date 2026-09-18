import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ruangbaca_kiosk/api/kiosk_api.dart';
import 'package:ruangbaca_kiosk/core/app_config.dart';
import 'package:ruangbaca_kiosk/features/visit/member_quick_visit.dart';
import 'package:ruangbaca_kiosk/models/models.dart';
import 'package:ruangbaca_kiosk/state/kiosk_controller.dart';

/// Membuktikan jalur cepat Buku Tamu: satu scan Member Key, tanpa isi form.
///
/// Server tiruan merekam body permintaan agar kita dapat memastikan payload QR
/// dan tujuan kunjungan benar-benar dikirim.
void main() {
  const purposeOptions = [
    SelectOption(value: 'read', label: 'Baca di tempat'),
    SelectOption(value: 'reference', label: 'Mencari referensi'),
  ];

  testWidgets('scan Member Key mencatat kunjungan tanpa mengisi form', (
    tester,
  ) async {
    final requests = <http.Request>[];

    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'visit': {
            'id': 91,
            'name': 'Rahmat Hidayat',
            'visited_at': '2026-06-07T03:00:00+07:00',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = KioskController(
      config: const AppConfig(
        baseUrl: 'https://contoh.test',
        apiKey: 'rbk_uji',
        deviceName: 'Kiosk Uji',
      ),
      api: KioskApi(
        config: const AppConfig(
          baseUrl: 'https://contoh.test',
          apiKey: 'rbk_uji',
          deviceName: 'Kiosk Uji',
        ),
        client: client,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: MemberQuickVisitCard(purposeOptions: purposeOptions),
          ),
        ),
      ),
    );

    // Kartu menawarkan jalur cepat, bukan form.
    expect(find.text('Punya akun anggota? Lewat sini'), findsOneWidget);
    expect(find.text('Scan & Catat Kehadiran'), findsOneWidget);

    // Tujuan bawaan = Baca di tempat (paling sering dipakai anggota).
    final readChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Baca di tempat'),
    );
    expect(readChip.selected, isTrue);

    // Pilih tujuan lain, lalu buka dialog scan.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mencari referensi'));
    await tester.pump();

    await tester.tap(find.text('Scan & Catat Kehadiran'));
    await tester.pumpAndSettle();

    // Dialog scan muncul dengan field scanner HID.
    expect(find.text('Buku Tamu Cepat'), findsOneWidget);
    final scanField = find.byType(TextField);
    expect(scanField, findsOneWidget);

    // Scanner HID mengetik payload lalu menekan Enter.
    await tester.enterText(scanField, 'MK-payload-uji');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // refreshBootstrapQuietly() juga memanggil API; saring hanya endpoint kunjungan.
    final visitRequests = requests
        .where((r) => r.url.path.endsWith('/api/kiosk/visits/member'))
        .toList();

    expect(visitRequests, hasLength(1));
    final body = jsonDecode(visitRequests.single.body) as Map<String, dynamic>;
    expect(body['verification_payload'], 'MK-payload-uji');
    expect(body['purpose'], 'reference');

    // Toast sukses muncul dan hilang sendiri.
    expect(find.text('Kunjungan Tercatat'), findsOneWidget);
    expect(find.textContaining('Rahmat Hidayat'), findsWidgets);

    controller.dispose();
  });
}
