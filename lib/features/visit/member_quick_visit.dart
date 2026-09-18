import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/kiosk_toast.dart';
import '../../widgets/member_key_dialog.dart';

/// Jalur cepat Buku Tamu untuk anggota: satu kali scan Member Key langsung
/// tercatat, tanpa mengisi kolom apa pun.
///
/// Ditampilkan di atas form manual pada menu Buku Tamu; form manual tetap
/// tersedia untuk pengunjung umum atau yang belum punya akun.
class MemberQuickVisitCard extends StatefulWidget {
  const MemberQuickVisitCard({super.key, required this.purposeOptions});

  final List<SelectOption> purposeOptions;

  @override
  State<MemberQuickVisitCard> createState() => _MemberQuickVisitCardState();
}

class _MemberQuickVisitCardState extends State<MemberQuickVisitCard> {
  /// Bawaan "Baca di tempat", tujuan yang paling sering dipakai anggota.
  String _purpose = 'read';
  bool _submitting = false;

  Future<void> _scanAndRecord() async {
    if (_submitting) return;

    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MemberKeyDialog(
        title: 'Buku Tamu Cepat',
        instructions:
            'Arahkan kode QR Member Key dari HP Anda ke scanner. Kehadiran '
            'langsung tercatat tanpa mengisi form.',
      ),
    );

    if (!mounted) return;
    if (payload == null || payload.trim().isEmpty) return;

    setState(() => _submitting = true);

    final controller = context.read<KioskController>();

    try {
      final result = await controller.recordMemberVisit(
        verificationPayload: payload.trim(),
        purpose: _purpose,
      );

      if (!mounted) return;
      KioskToast.show(
        context,
        title: 'Kunjungan Tercatat',
        message: 'Terima kasih, ${result.name}. Kehadiran Anda telah dicatat.',
        detail: 'Waktu: ${_formatTime(result.visitedAt)}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.bestMessage),
          backgroundColor: KioskTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KioskTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KioskTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KioskTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: KioskTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punya akun anggota? Lewat sini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Scan Member Key, data Anda terisi otomatis.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tujuan kunjungan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.purposeOptions
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selected: _purpose == option.value,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _purpose = option.value),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _scanAndRecord,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_2),
            label: Text(
              _submitting ? 'Menyimpan...' : 'Scan & Catat Kehadiran',
            ),
          ),
        ],
      ),
    );
  }
}
