import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangbaca_kiosk/features/kiosk/kiosk_exit.dart';

/// Membuktikan kiosk tidak dapat ditutup tanpa konfirmasi yang disengaja.
void main() {
  testWidgets('dialog keluar menolak frasa yang salah', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await showDialog<bool>(
                context: context,
                builder: (_) => const KioskExitDialog(),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Tombol "Keluar" harus nonaktif sejak awal: hanya membuka dialog
    // tidak boleh cukup untuk menutup kiosk.
    final keluar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Keluar'),
    );
    expect(keluar.onPressed, isNull, reason: 'tombol Keluar harus nonaktif');

    // Frasa salah tetap tidak mengaktifkan tombol.
    await tester.enterText(find.byType(TextField), 'BUKA');
    await tester.pump();
    final masihNonaktif = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Keluar'),
    );
    expect(masihNonaktif.onPressed, isNull);

    // Menekan tombol yang nonaktif tidak menutup dialog.
    await tester.tap(find.text('Keluar'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(KioskExitDialog), findsOneWidget);
  });

  testWidgets('frasa benar mengaktifkan tombol dan mengembalikan true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const KioskExitDialog(),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Huruf kecil pun diterima: pengguna tidak dihukum karena kapitalisasi.
    await tester.enterText(find.byType(TextField), 'keluar');
    await tester.pump();

    final aktif = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Keluar'),
    );
    expect(aktif.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(KioskExitDialog), findsNothing);
  });

  testWidgets('tombol Batal menutup dialog tanpa keluar', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const KioskExitDialog(),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  test('frasa keluar adalah "KELUAR" dan tidak kosong', () {
    expect(kioskExitPhrase, 'KELUAR');
    expect(kioskExitPhrase.trim(), isNotEmpty);
  });
}
