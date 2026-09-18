import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/kiosk_controller.dart';
import 'feedback.dart';

/// Dialog pencarian & pemilihan buku.
///
/// - mode `borrow`: cari buku yang dapat dipinjam.
/// - mode `return`: menampilkan buku yang sedang dipinjam anggota.
class BookPickerDialog extends StatefulWidget {
  const BookPickerDialog({
    super.key,
    required this.mode,
    this.memberIdentifier,
    this.selectedIds = const <int>[],
  });

  final String mode;
  final String? memberIdentifier;
  final List<int> selectedIds;

  @override
  State<BookPickerDialog> createState() => _BookPickerDialogState();
}

class _BookPickerDialogState extends State<BookPickerDialog> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;

  List<KioskBook> _results = const <KioskBook>[];
  bool _loading = false;
  String? _error;
  late Set<int> _selected;

  bool get _isReturn => widget.mode == 'return';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedIds};
    unawaited(_search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search());
    });
  }

  Future<void> _search() async {
    final controller = context.read<KioskController>();
    final query = _queryController.text.trim();

    if (_isReturn && (widget.memberIdentifier ?? '').isEmpty) {
      setState(() {
        _error = 'Identitas anggota wajib diisi lebih dulu.';
        _results = const <KioskBook>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final books = await controller.searchBooks(
        query: query,
        mode: widget.mode,
        memberIdentifier: widget.memberIdentifier,
      );
      if (!mounted) return;
      setState(() {
        _results = books;
        _loading = false;
        if (_isReturn) {
          _selected = books.map((book) => book.id).toSet();
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.bestMessage;
        _results = const <KioskBook>[];
      });
    }
  }

  void _toggle(KioskBook book) {
    setState(() {
      if (_selected.contains(book.id)) {
        _selected.remove(book.id);
      } else {
        _selected.add(book.id);
      }
    });
  }

  void _confirm() {
    final chosen = _results
        .where((book) => _selected.contains(book.id))
        .toList(growable: false);
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: KioskTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isReturn
                          ? 'Buku yang sedang dipinjam'
                          : 'Cari & pilih buku',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isReturn)
                TextField(
                  controller: _queryController,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => unawaited(_search()),
                  decoration: const InputDecoration(
                    hintText: 'Ketik judul, penulis, atau ISBN lalu Enter',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              if (_isReturn)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KioskTheme.border),
                  ),
                  child: Text(
                    'Anggota: ${widget.memberIdentifier ?? '-'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                StatusBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          _isReturn
                              ? 'Tidak ada pinjaman aktif untuk identitas ini.'
                              : 'Belum ada hasil. Ketik kata kunci untuk mencari.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13.5,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final book = _results[index];
                          final isSelected = _selected.contains(book.id);
                          return _BookTile(
                            book: book,
                            isSelected: isSelected,
                            onTap: () => _toggle(book),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '${_selected.length} buku dipilih',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(110, 48),
                    ),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _selected.isEmpty ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(130, 48),
                    ),
                    child: const Text('Gunakan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.isSelected,
    required this.onTap,
  });

  final KioskBook book;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? KioskTheme.primary.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? KioskTheme.primary.withValues(alpha: 0.45)
                  : KioskTheme.border,
            ),
          ),
          child: Row(
            children: [
              _BookCover(url: book.coverImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2233),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.authorsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${book.identifierLabel} · ${book.availableItemsCount} '
                      'tersedia dari ${book.itemsCount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Checkbox(value: isSelected, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final valid = url != null && url!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 64,
        child: valid
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _CoverFallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _CoverFallback();
                },
              )
            : const _CoverFallback(),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F2F7),
      child: const Icon(
        Icons.menu_book_outlined,
        size: 22,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}
