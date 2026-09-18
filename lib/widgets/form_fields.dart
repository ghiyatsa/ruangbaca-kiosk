import 'package:flutter/material.dart';

/// Label + isi untuk satu field form kiosk.
class KioskField extends StatelessWidget {
  const KioskField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.errorText,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (required)
              const Text(' *', style: TextStyle(color: Color(0xFFB91C1C))),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
        ],
      ],
    );
  }
}

/// Baris responsif: beberapa kolom berdampingan, atau bertumpuk bila sempit.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 560,
  });

  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    final isNarrow = MediaQuery.sizeOf(context).width < breakpoint;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}
