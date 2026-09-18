import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/kiosk_controller.dart';
import 'hid_scan_field.dart';
import 'qr_webcam_scanner.dart';

/// Dialog verifikasi QR (Member Key) untuk pinjam/kembali.
///
/// Mendukung dua jalur: scanner HID/USB (input teks + Enter) dan webcam
/// (bila diaktifkan di konfigurasi). Mengembalikan payload QR via
/// `Navigator.pop(context, payload)`.
class MemberKeyDialog extends StatefulWidget {
  const MemberKeyDialog({
    super.key,
    required this.title,
    required this.instructions,
  });

  final String title;
  final String instructions;

  @override
  State<MemberKeyDialog> createState() => _MemberKeyDialogState();
}

class _MemberKeyDialogState extends State<MemberKeyDialog> {
  bool _webcamEnabled = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();
    final webcamAvailable = controller.config.enableWebcamScanner;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: KioskTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      color: KioskTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.instructions,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              HidScanField(
                label: 'Scanner USB / HID',
                hintText: 'Scan Member Key di sini',
                enabled: !_webcamEnabled,
                autofocus: !_webcamEnabled,
                onSubmit: (payload) => Navigator.of(context).pop(payload),
              ),
              if (webcamAvailable) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Atau gunakan kamera',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Switch(
                      value: _webcamEnabled,
                      onChanged: (value) =>
                          setState(() => _webcamEnabled = value),
                    ),
                  ],
                ),
                if (_webcamEnabled)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: Colors.black,
                        child: QrWebcamScanner(
                          active: _webcamEnabled,
                          overlayHint: 'Arahkan QR ke kamera',
                          onDetected: (payload) =>
                              Navigator.of(context).pop(payload),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
