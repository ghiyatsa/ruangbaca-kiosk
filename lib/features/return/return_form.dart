import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../api/idempotency.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/feedback.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/kiosk_toast.dart';
import '../../widgets/member_key_dialog.dart';

/// Layanan Kembalikan Buku.
///
/// Alur: masukkan identitas, daftar pinjaman aktif dimuat otomatis, pilih
/// buku, scan Member Key, lalu kirim.
class ReturnForm extends StatefulWidget {
  const ReturnForm({super.key});

  @override
  State<ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends State<ReturnForm> {
  final _identifierController = TextEditingController();
  final _idempotency = IdempotencyKey();
  Timer? _debounce;

  List<KioskBook> _borrowedBooks = const <KioskBook>[];
  final Set<int> _selectedIds = <int>{};

  bool _loadingBooks = false;
  bool _submitting = false;
  String? _booksError;
  String? _error;

  String get _identifier => _identifierController.text.trim();

  /// Basis key idempotency: identitas anggota + daftar buku (urut) agar sama
  /// untuk setiap percobaan ulang transaksi yang sama.
  String get _idempotencyBasis {
    final ids = _selectedIds.toList()..sort();
    return 'return|$_identifier|${ids.join(',')}';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _identifierController.dispose();
    super.dispose();
  }

  void _onIdentifierChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_loadBorrowedBooks());
    });
    setState(() {});
  }

  Future<void> _loadBorrowedBooks() async {
    final identifier = _identifier;
    if (identifier.isEmpty) {
      setState(() {
        _borrowedBooks = const <KioskBook>[];
        _selectedIds.clear();
        _booksError = null;
        _loadingBooks = false;
      });
      return;
    }

    setState(() {
      _loadingBooks = true;
      _booksError = null;
    });

    final controller = context.read<KioskController>();

    try {
      final result = await controller.searchBooks(
        mode: 'return',
        memberIdentifier: identifier,
      );
      if (!mounted || identifier != _identifier) return;
      setState(() {
        _borrowedBooks = result.books;
        _selectedIds
          ..clear()
          ..addAll(result.books.map((book) => book.id));
        _loadingBooks = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _borrowedBooks = const <KioskBook>[];
        _selectedIds.clear();
        _loadingBooks = false;
        _booksError = error.bestMessage;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = context.read<KioskController>();

    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MemberKeyDialog(
        title: 'Verifikasi Pengembalian',
        instructions:
            'Arahkan kode QR Member Key dari HP anggota ke scanner untuk '
            'menyelesaikan pengembalian.',
      ),
    );

    if (!mounted) return;

    if (payload == null || payload.trim().isEmpty) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final bookIds = _selectedIds.toList(growable: false);

    try {
      final result = await controller.returnBooks(
        verificationPayload: payload.trim(),
        memberIdentifier: _identifier,
        bookIds: bookIds,
        // Key stabil: percobaan ulang transaksi yang sama memakai key yang
        // sama, sehingga server tidak memproses pengembalian dua kali bila
        // permintaan pertama sudah diproses tetapi responsnya hilang.
        idempotencyKey: _idempotency.forBasis(_idempotencyBasis),
      );

      if (!mounted) return;
      _idempotency.clear();
      _reset();
      KioskToast.show(
        context,
        title: 'Pengembalian Berhasil',
        message: result.message.isNotEmpty
            ? result.message
            : '${result.returnedCount} buku berhasil dikembalikan.',
        detail: 'Anggota: ${result.memberName}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = transactionErrorMessage(error, 'Pengembalian'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _idempotency.clear();
    _identifierController.clear();
    setState(() {
      _borrowedBooks = const <KioskBook>[];
      _selectedIds.clear();
      _error = null;
      _booksError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Server tak terjangkau: pencarian anggota dan pengembalian pasti gagal.
    final offline = context.watchOffline();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            StatusBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          KioskField(
            label: 'Identitas Anggota',
            required: true,
            child: TextField(
              controller: _identifierController,
              autofocus: true,
              onChanged: _onIdentifierChanged,
              decoration: const InputDecoration(
                hintText: 'Contoh: 210170001 atau nama@unimal.ac.id',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_booksError != null) ...[
            StatusBanner(
              title: 'Daftar pinjaman belum tersedia',
              message: _booksError!,
            ),
            const SizedBox(height: 14),
          ],
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KioskTheme.border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Buku yang sedang dipinjam',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedIds.length} dipilih',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _bookListBody(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: (_selectedIds.isEmpty || _submitting || offline)
                ? null
                : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.assignment_return_outlined),
            label: Text(
              _submitting
                  ? 'Memproses...'
                  : 'Kembalikan ${_selectedIds.length} Buku',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookListBody() {
    if (_identifier.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text(
          'Masukkan identitas anggota untuk melihat daftar pinjaman aktif.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
        ),
      );
    }

    if (_loadingBooks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_borrowedBooks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text(
          'Tidak ada pinjaman aktif untuk identitas ini.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _borrowedBooks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _borrowedBooks[index];
        final isSelected = _selectedIds.contains(book.id);

        return Material(
          color: isSelected
              ? KioskTheme.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              if (isSelected) {
                _selectedIds.remove(book.id);
              } else {
                _selectedIds.add(book.id);
              }
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? KioskTheme.primary.withValues(alpha: 0.45)
                      : KioskTheme.border,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => setState(() {
                      if (isSelected) {
                        _selectedIds.remove(book.id);
                      } else {
                        _selectedIds.add(book.id);
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${book.authorsLabel} · ${book.identifierLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
