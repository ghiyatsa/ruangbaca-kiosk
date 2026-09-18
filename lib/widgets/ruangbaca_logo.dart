import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';

/// Logo Ruang Baca Informatika, dari `assets/ruangbaca-logo.svg`. Bentuknya
/// sama dengan `resources/js/components/common/RuangBacaLogo.tsx` di web.
///
/// SVG digambar dengan `stroke="#000000"` lalu diwarnai ulang lewat
/// [ColorFilter], sehingga satu aset bisa dipakai untuk warna apa pun.
/// `stroke-opacity` dipertahankan sebagai alpha agar goresan bertingkat pada
/// "halaman buku" tetap terlihat.
class RuangBacaLogo extends StatelessWidget {
  const RuangBacaLogo({
    super.key,
    this.size = 64,
    this.color = KioskTheme.primary,
    this.semanticLabel = 'Logo Ruang Baca Informatika',
  });

  /// Sisi terpanjang logo dalam piksel logis.
  final double size;

  /// Warna goresan logo.
  final Color color;

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/ruangbaca-logo.svg',
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
