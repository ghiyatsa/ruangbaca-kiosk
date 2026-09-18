import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/feedback.dart';

/// Dialog QR penautan akun Google untuk registrasi anggota.
///
/// Menampilkan QR dari server, hitung mundur kedaluwarsa, dan polling status
/// tiap 3 detik sampai berhasil atau kedaluwarsa.
class MemberClaimDialog extends StatefulWidget {
  const MemberClaimDialog({
    super.key,
    required this.initialClaim,
    required this.onLinked,
    required this.onCancel,
    required this.onRestart,
  });

  final MemberClaim initialClaim;
  final VoidCallback onLinked;
  final VoidCallback onCancel;
  final VoidCallback onRestart;

  @override
  State<MemberClaimDialog> createState() => _MemberClaimDialogState();
}

class _MemberClaimDialogState extends State<MemberClaimDialog> {
  late MemberClaim _claim = widget.initialClaim;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _polling = false;
  bool _finalizing = false;

  bool get _isPending => _claim.status == MemberClaimStatus.pending;
  bool get _isCompleted => _claim.status.isCompleted;

  @override
  void initState() {
    super.initState();
    _computeRemaining();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _computeRemaining(),
    );
    if (_isPending) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_poll()),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _computeRemaining() {
    final expiresAt = _claim.expiresAt;
    if (expiresAt == null) {
      if (mounted) setState(() => _secondsRemaining = 0);
      return;
    }
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    if (!mounted) return;

    // Kedaluwarsa lokal: server mungkin tidak dapat dipantau (mis. autentikasi
    // hanya dengan API key tanpa device token), jadi hitung mundur menjadi
    // sumber kebenaran untuk batas waktu.
    if (remaining <= 0 && _isPending) {
      _pollTimer?.cancel();
      setState(() {
        _secondsRemaining = 0;
        _claim = MemberClaim(id: _claim.id, status: MemberClaimStatus.expired);
      });
      return;
    }

    setState(() => _secondsRemaining = remaining < 0 ? 0 : remaining);
  }

  Future<void> _poll() async {
    if (_polling || !_isPending) return;
    _polling = true;

    try {
      final controller = context.read<KioskController>();
      final updated = await controller.memberRegistrationStatus();
      if (!mounted) return;

      if (updated == null) {
        // Endpoint status memerlukan device token. Bila kiosk hanya memakai
        // API key, server mengembalikan `claim: null` walaupun pendaftaran
        // berjalan. Jangan anggap kedaluwarsa; biarkan hitung mundur lokal
        // yang menentukan, lalu lanjutkan polling.
        return;
      }

      setState(() => _claim = updated);

      if (updated.status.isCompleted && !updated.approvalPending) {
        _pollTimer?.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) await _finalize(dismiss: true);
      } else if (updated.status == MemberClaimStatus.expired) {
        _pollTimer?.cancel();
      }
    } on ApiException {
      // Abaikan galat polling sementara.
    } finally {
      _polling = false;
    }
  }

  Future<void> _finalize({required bool dismiss}) async {
    if (_finalizing) return;
    _finalizing = true;

    try {
      final controller = context.read<KioskController>();
      await controller.cancelMemberRegistration();
    } catch (_) {
      // Abaikan.
    } finally {
      _pollTimer?.cancel();
      if (mounted) {
        Navigator.of(context).pop();
        if (dismiss) {
          widget.onLinked();
        }
      }
    }
  }

  String get _countdownLabel {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final lowTime = _secondsRemaining < 60 && _isPending;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusBadge(claim: _claim),
              const SizedBox(height: 16),
              Text(
                _title(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              if (_isPending && _claim.hasQr)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: lowTime
                          ? const Color(0xFFEF4444)
                          : KioskTheme.primary,
                      width: 2,
                    ),
                  ),
                  child: SvgPicture.string(
                    _claim.qrSvg!,
                    width: 220,
                    height: 220,
                  ),
                ),
              if (_isPending) ...[
                const SizedBox(height: 18),
                Text(
                  _countdownLabel,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: lowTime
                        ? const Color(0xFFB91C1C)
                        : KioskTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan sekarang',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
              if (_isCompleted) ...[
                const SizedBox(height: 8),
                Icon(
                  _claim.approvalPending
                      ? Icons.hourglass_top
                      : Icons.check_circle,
                  size: 54,
                  color: _claim.approvalPending
                      ? KioskTheme.warning
                      : KioskTheme.success,
                ),
                const SizedBox(height: 12),
                StatusBanner(
                  tone: _claim.approvalPending
                      ? StatusTone.warning
                      : StatusTone.success,
                  title: _claim.approvalPending
                      ? 'Menunggu persetujuan admin'
                      : 'Akun Google berhasil ditautkan',
                  message: _claim.approvalPending
                      ? 'Petugas akan memverifikasi pendaftaran. Simpan nomor '
                            'WhatsApp untuk informasi selanjutnya.'
                      : 'Data pendaftaran sudah terhubung dengan akun Google.',
                ),
              ],
              if (_claim.lastErrorMessage != null &&
                  _claim.lastErrorMessage!.isNotEmpty) ...[
                const SizedBox(height: 14),
                StatusBanner(
                  title: 'Penautan belum berhasil',
                  message: _claim.lastErrorMessage!,
                ),
              ],
              const SizedBox(height: 22),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  String _title() {
    if (_isCompleted) {
      return _claim.approvalPending
          ? 'Pendaftaran Terkirim!'
          : 'Pendaftaran Berhasil!';
    }
    if (_claim.status == MemberClaimStatus.expired) {
      return 'QR Kedaluwarsa';
    }
    return 'Tautkan Akun Google';
  }

  String _subtitle() {
    if (_isCompleted) {
      return _claim.approvalPending
          ? 'Akun Google telah terhubung. Akun menunggu persetujuan admin '
                'sebelum dapat digunakan meminjam.'
          : 'Akun Google Anda telah terhubung dengan data pendaftaran.';
    }
    if (_claim.status == MemberClaimStatus.expired) {
      return 'Batas waktu penautan telah habis. Buat QR baru untuk mencoba lagi.';
    }
    return 'Pindai QR ini dengan ponsel untuk masuk memakai Google dan '
        'menyelesaikan pendaftaran.';
  }

  Widget _actions() {
    if (_isCompleted) {
      return FilledButton(
        onPressed: () => _finalize(dismiss: true),
        child: const Text('Selesai'),
      );
    }

    if (_claim.status == MemberClaimStatus.expired) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCancel();
              },
              child: const Text('Tutup'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRestart();
              },
              child: const Text('Buat QR Baru'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCancel();
            },
            child: const Text('Batalkan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.claim});

  final MemberClaim claim;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (claim.status) {
      MemberClaimStatus.pending => (KioskTheme.primary, 'MENUNGGU SCAN'),
      MemberClaimStatus.linked ||
      MemberClaimStatus.claimed => (KioskTheme.success, 'TERHUBUNG'),
      MemberClaimStatus.expired => (KioskTheme.danger, 'KEDALUWARSA'),
      _ => (const Color(0xFF6B7280), claim.status.label.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: color,
        ),
      ),
    );
  }
}
