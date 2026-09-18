import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangbaca_kiosk/widgets/ruangbaca_logo.dart';

/// Membuktikan aset logo Ruang Baca benar-benar terpaket dan dirender, bukan
/// ikon Material generik.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aset logo ikut terpaket dan memuat goresan logo web', () async {
    final data = await rootBundle.load('assets/ruangbaca-logo.svg');
    expect(data.lengthInBytes, greaterThan(0));

    final svg = utf8.decode(data.buffer.asUint8List());
    expect(svg, contains('<svg'));
    // Path khas logo Ruang Baca. Bila aset tergantikan gambar lain atau
    // gagal terpaket, uji ini gagal.
    expect(svg, contains('M1063.465,2681.729l1273.07,0'));
    expect(svg, contains('M1148.294,2220.218l559.706,-520.218'));
    // Sepuluh goresan: 4 sisi bingkai + panah + garis + 4 goresan halaman.
    expect('<path'.allMatches(svg).length, 10);
  });

  testWidgets('RuangBacaLogo merender SVG, bukan ikon Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: RuangBacaLogo(size: 64))),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
  });

  testWidgets('ukuran logo mengikuti parameter size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: RuangBacaLogo(size: 38))),
      ),
    );
    await tester.pump();

    final box = tester.getSize(find.byType(RuangBacaLogo));
    expect(box.width, 38);
    expect(box.height, 38);
  });
}
