import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../api/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/book_picker_dialog.dart';
import '../../widgets/feedback.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/kiosk_toast.dart';
import '../../widgets/member_key_dialog.dart';

/// Layanan Pinjam Buku: peminjaman mandiri di kiosk.
///
/// Alur: masukkan identitas, pilih buku, scan Member Key, lalu kirim.
class BorrowForm extends StatefulWidget {
  const BorrowForm({super.key, required this.loanMaxBooks});

  final int loanMaxBooks;

  @override
  State<BorrowForm> createState() => _BorrowFormState();
}

class _BorrowFormState extends State<BorrowForm> {
  final _identifierController = TextEditingController();

  final List<KioskBook> _selectedBooks = <KioskBook>[];
  bool _submitting = false;
  String? _error;

  String get _identifier => _identifierController.text.trim();
  bool get _isComplete => _identifier.isNotEmpty && _selectedBooks.isNotEmpty;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _pickBooks() async {
    final selected = await showDialog<List<KioskBook>>(
      context: context,
      builder: (_) => BookPickerDialog(
        mode: 'borrow',
        selectedIds: _selectedBooks.map((book) => book.id).toList(),
      ),
    );

    if (selected == null) return;

    setState(() {
      _selectedBooks
        ..clear()
        ..addAll(selected.take(widget.loanMaxBooks));
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_isComplete || _submitting) return;

    final controller = context.read<KioskController>();

    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MemberKeyDialog(
        title: 'Verifikasi Peminjaman',
        instructions:
            'Arahkan kode QR Member Key dari HP anggota ke scanner untuk '
            'menyelesaikan peminjaman.',
      ),
    );

    if (!mounted) return;

    if (payload == null || payload.trim().isEmpty) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final bookIds = _selectedBooks
        .map((book) => book.id)
        .toList(growable: false);

    try {
      final result = await controller.borrowBooks(
        verificationPayload: payload.trim(),
        memberIdentifier: _identifier,
        bookIds: bookIds,
        idempotencyKey: const Uuid().v4(),
      );

      if (!mounted) return;
      _reset();
      KioskToast.show(
        context,
        title: 'Peminjaman Berhasil',
        message: result.message.isNotEmpty
            ? result.message
            : 'Peminjaman untuk ${result.memberName} berhasil disimpan.',
        detail:
            '${result.booksCount} buku · Jatuh tempo: '
            '${_formatDate(result.dueAt)}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.bestMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _identifierController.clear();
    setState(() {
      _selectedBooks.clear();
      _error = null;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Contoh: 210170001 atau nama@unimal.ac.id',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SelectedBooksPanel(
            books: _selectedBooks,
            maxBooks: widget.loanMaxBooks,
            onPick: _pickBooks,
            onRemove: (book) => setState(() {
              _selectedBooks.removeWhere((item) => item.id == book.id);
            }),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: (!_isComplete || _submitting) ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_scanner),
            label: Text(_submitting ? 'Memproses...' : 'Lanjutkan Peminjaman'),
          ),
          if (!_isComplete) ...[
            const SizedBox(height: 8),
            const Text(
              'Isi identitas anggota dan pilih minimal satu buku.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel daftar buku terpilih, dipakai bersama alur pinjam.
class _SelectedBooksPanel extends StatelessWidget {
  const _SelectedBooksPanel({
    required this.books,
    required this.maxBooks,
    required this.onPick,
    required this.onRemove,
  });

  final List<KioskBook> books;
  final int maxBooks;
  final VoidCallback onPick;
  final ValueChanged<KioskBook> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KioskTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Buku dipilih',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${books.length} / $maxBooks',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: books.length >= maxBooks ? null : onPick,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Cari Buku'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Text(
                'Belum ada buku dipilih.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final book = books[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KioskTheme.border),
                  ),
                  child: Row(
                    children: [
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
                              '${book.authorsLabel} | ${book.identifierLabel}',
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
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => onRemove(book),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
