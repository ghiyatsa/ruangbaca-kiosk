import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangbaca_kiosk/features/kiosk/kiosk_menu.dart';
import 'package:ruangbaca_kiosk/features/kiosk/kiosk_shortcut.dart';
import 'package:ruangbaca_kiosk/features/member/member_email.dart';
import 'package:ruangbaca_kiosk/models/models.dart';

/// Pemanggil ringkas `KioskShortcut.resolve` untuk pengujian.
KioskMenu? shortcut(
  LogicalKeyboardKey key, {
  bool alt = false,
  bool ctrl = false,
  bool meta = false,
  bool shift = false,
}) {
  return KioskShortcut.resolve(
    keyLabel: key.keyLabel,
    altPressed: alt,
    ctrlPressed: ctrl,
    metaPressed: meta,
    shiftPressed: shift,
  );
}

void main() {
  group('pintasan menu (Alt + angka)', () {
    test('Alt+1..Alt+4 memilih keempat menu', () {
      expect(shortcut(LogicalKeyboardKey.digit1, alt: true), KioskMenu.visit);
      expect(shortcut(LogicalKeyboardKey.digit2, alt: true), KioskMenu.member);
      expect(shortcut(LogicalKeyboardKey.digit3, alt: true), KioskMenu.borrow);
      expect(
        shortcut(LogicalKeyboardKey.digit4, alt: true),
        KioskMenu.returnBook,
      );
    });

    test('angka polos TIDAK memilih menu (tidak bentrok dengan isian)', () {
      for (final key in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ]) {
        expect(shortcut(key), isNull, reason: '${key.keyLabel} tanpa Alt');
      }
    });

    test('keypad juga dikenali saat Alt ditekan', () {
      expect(shortcut(LogicalKeyboardKey.numpad1, alt: true), KioskMenu.visit);
      expect(
        shortcut(LogicalKeyboardKey.numpad4, alt: true),
        KioskMenu.returnBook,
      );
    });

    test('kombinasi lain diabaikan', () {
      expect(
        shortcut(LogicalKeyboardKey.digit1, alt: true, ctrl: true),
        isNull,
      );
      expect(
        shortcut(LogicalKeyboardKey.digit1, alt: true, meta: true),
        isNull,
      );
      expect(
        shortcut(LogicalKeyboardKey.digit1, alt: true, shift: true),
        isNull,
      );
      expect(shortcut(LogicalKeyboardKey.digit1, ctrl: true), isNull);
    });

    test('tombol bukan angka diabaikan', () {
      expect(shortcut(LogicalKeyboardKey.keyA, alt: true), isNull);
      expect(shortcut(LogicalKeyboardKey.escape, alt: true), isNull);
      expect(shortcut(LogicalKeyboardKey.digit5, alt: true), isNull);
      expect(shortcut(LogicalKeyboardKey.digit0, alt: true), isNull);
    });

    test('label pintasan memakai awalan Alt', () {
      expect(KioskMenu.visit.shortcutLabel, 'Alt+1');
      expect(KioskMenu.returnBook.shortcutLabel, 'Alt+4');
      expect(KioskShortcut.modifierLabel, 'Alt');
    });
  });

  group('member email helpers', () {
    test('composeMemberEmail joins local part and domain', () {
      expect(
        composeMemberEmail('Siti', '@mhs.unimal.ac.id'),
        'siti@mhs.unimal.ac.id',
      );
      expect(composeMemberEmail('', ''), '');
    });

    test('splitMemberEmail extracts parts', () {
      final parts = splitMemberEmail('siti@mhs.unimal.ac.id');
      expect(parts.localPart, 'siti');
      expect(parts.domain, 'mhs.unimal.ac.id');
    });

    test('validateMemberEmail rejects non-campus domains', () {
      expect(validateMemberEmail('siti', 'gmail.com'), isNotNull);
      expect(validateMemberEmail('siti', 'mhs.unimal.ac.id'), isNull);
      expect(validateMemberEmail('', 'mhs.unimal.ac.id'), isNotNull);
    });
  });

  group('model parsing', () {
    test('BootstrapData parses options and stats', () {
      final data = BootstrapData.fromJson({
        'loan_max_books': 3,
        'visitor_type_options': {'mahasiswa': 'Mahasiswa', 'umum': 'Umum'},
        'purpose_options': {'read': 'Baca di tempat'},
        'session': {
          'timezone': 'Asia/Jakarta',
          'operatingOpenTime': '07:00',
          'operatingCloseTime': '21:00',
          'withinOperatingHours': true,
        },
        'stats': {
          'deviceId': 'KIOSK-01',
          'ipAddress': '10.0.0.5',
          'todayVisits': 12,
          'todayBorrowed': 4,
          'todayReturned': 2,
        },
      });

      expect(data.loanMaxBooks, 3);
      expect(data.visitorTypeOptions.length, 2);
      expect(data.visitorTypeOptions.first.label, 'Mahasiswa');
      expect(data.session.withinOperatingHours, isTrue);
      expect(data.stats.todayVisits, 12);
    });

    test('KioskBook parses authors and availability', () {
      final book = KioskBook.fromJson({
        'id': 42,
        'title': 'Algoritma dan Pemrograman',
        'authors': [
          {'id': 7, 'name': 'Rinaldi Munir'},
        ],
        'availableItemsCount': 2,
        'itemsCount': 3,
        'isbn': '9786021516036',
        'coverImageUrl': 'https://example.com/cover.jpg',
      });

      expect(book.id, 42);
      expect(book.authors, ['Rinaldi Munir']);
      expect(book.authorsLabel, 'Rinaldi Munir');
      expect(book.identifierLabel, 'ISBN 9786021516036');
      expect(book.availableItemsCount, 2);
    });

    test('KioskBookSearchResult parses books and ignores legacy extras', () {
      // Server lama masih mengirim suggestions/corrected_query; model harus
      // tetap mem-parse daftar buku tanpa error.
      final result = KioskBookSearchResult.fromJson({
        'books': [
          {
            'id': 1,
            'title': 'Metode Penelitian',
            'authors': ['A'],
          },
        ],
        'suggestions': ['metode penelitian kualitatif', 'metode'],
        'corrected_query': 'metode',
      });

      expect(result.books, hasLength(1));
      expect(result.books.first.title, 'Metode Penelitian');
    });

    test('KioskBookSearchResult tolerates missing fields', () {
      final result = KioskBookSearchResult.fromJson(const {});

      expect(result.books, isEmpty);
    });

    test('MemberClaim.fromStatusJson maps approval_pending', () {
      final claim = MemberClaim.fromStatusJson({
        'id': 88,
        'status': 'claimed',
        'approval_pending': true,
        'last_error_message': null,
      });

      expect(claim.status, MemberClaimStatus.claimed);
      expect(claim.status.isCompleted, isTrue);
      expect(claim.approvalPending, isTrue);
    });

    test('LoanResult parses nested loan payload', () {
      final loan = LoanResult.fromJson({
        'loan': {
          'id': 555,
          'member': {'name': 'Ahmad Fauzi'},
          'books_count': 2,
          'borrowed_at': '2026-09-16T13:10:00+07:00',
          'due_at': '2026-09-23T13:10:00+07:00',
        },
        'message': 'Peminjaman berhasil.',
      });

      expect(loan.id, 555);
      expect(loan.memberName, 'Ahmad Fauzi');
      expect(loan.booksCount, 2);
      expect(loan.dueAt, isNotNull);
    });

    test('ReturnResult parses returned_count', () {
      final result = ReturnResult.fromJson({
        'returned_count': 1,
        'member': {'id': 9, 'name': 'Ahmad Fauzi'},
        'message': '1 buku berhasil dikembalikan.',
      });

      expect(result.returnedCount, 1);
      expect(result.memberName, 'Ahmad Fauzi');
      expect(result.memberId, 9);
    });
  });
}
