import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kolom input untuk scanner QR HID/USB (yang berperilaku seperti keyboard).
///
/// Scanner HID mengetikkan isi QR lalu menekan Enter. Widget ini menangkap
/// Enter sebagai sinyal "QR selesai" dan memanggil [onSubmit].
class HidScanField extends StatefulWidget {
  const HidScanField({
    super.key,
    required this.onSubmit,
    this.hintText = 'Scan QR di sini',
    this.label,
    this.enabled = true,
    this.autofocus = true,
  });

  final ValueChanged<String> onSubmit;
  final String hintText;
  final String? label;
  final bool enabled;
  final bool autofocus;

  @override
  State<HidScanField> createState() => _HidScanFieldState();
}

class _HidScanFieldState extends State<HidScanField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    _controller.clear();
    if (value.isNotEmpty) {
      widget.onSubmit(value);
    }
    // Kembalikan fokus agar scan berikutnya langsung tertangkap.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
          ],
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.qr_code_scanner),
            suffixIcon: IconButton(
              tooltip: 'Kirim',
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scanner USB: arahkan QR ke alat, isian akan terkirim otomatis.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
