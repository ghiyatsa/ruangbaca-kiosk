import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangbaca_kiosk/widgets/kiosk_toast.dart';

/// Membangun host minimal yang menyediakan `Overlay` (dibutuhkan toast).
Future<BuildContext> pumpHost(WidgetTester tester) async {
  late BuildContext hostContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );

  return hostContext;
}

void main() {
  group('KioskToast', () {
    testWidgets('tampil, tanpa tombol, lalu hilang sendiri', (tester) async {
      final context = await pumpHost(tester);

      KioskToast.show(
        context,
        title: 'Peminjaman Berhasil',
        message: 'Peminjaman untuk Ahmad berhasil disimpan.',
        detail: '2 buku · Jatuh tempo: 25/09/2026',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Peminjaman Berhasil'), findsOneWidget);
      expect(find.text('2 buku · Jatuh tempo: 25/09/2026'), findsOneWidget);

      // Inti permintaan: tidak ada tombol yang harus ditekan.
      expect(find.widgetWithText(FilledButton, 'Selesai'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Selesai'), findsNothing);
      expect(find.text('Selesai'), findsNothing);

      // Toast menutup sendiri setelah durasi bawaan.
      await tester.pump(KioskToast.defaultDuration);
      await tester.pumpAndSettle();

      expect(find.text('Peminjaman Berhasil'), findsNothing);
    });

    testWidgets('tidak menghalangi sentuhan di belakangnya', (tester) async {
      final context = await pumpHost(tester);

      var tapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (inner) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => tapped++,
                  child: const Text('Tombol Belakang'),
                ),
              ),
            ),
          ),
        ),
      );

      KioskToast.show(context, title: 'Kunjungan Tercatat');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Toast memakai IgnorePointer, jadi tombol di belakang tetap bisa ditekan.
      await tester.tap(find.text('Tombol Belakang'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('toast baru menggantikan yang lama (tidak menumpuk)', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      KioskToast.show(context, title: 'Peminjaman Berhasil');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Peminjaman Berhasil'), findsOneWidget);

      KioskToast.show(context, title: 'Pengembalian Berhasil');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Pengembalian Berhasil'), findsOneWidget);
      expect(find.text('Peminjaman Berhasil'), findsNothing);

      await tester.pump(KioskToast.defaultDuration);
      await tester.pumpAndSettle();
      expect(find.text('Pengembalian Berhasil'), findsNothing);
    });

    testWidgets('dismiss menutup toast segera', (tester) async {
      final context = await pumpHost(tester);

      KioskToast.show(context, title: 'Kunjungan Tercatat');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Kunjungan Tercatat'), findsOneWidget);

      KioskToast.dismiss();
      await tester.pumpAndSettle();

      expect(find.text('Kunjungan Tercatat'), findsNothing);
    });
  });
}
