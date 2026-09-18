import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';

/// Logo Ruang Baca Informatika.
///
/// Bentuknya disalin persis dari komponen web
/// `resources/js/components/common/RuangBacaLogo.tsx` (SVG 10 path) agar
/// tampilan kiosk desktop identik dengan kiosk web. Sebelumnya kiosk desktop
/// memakai ikon Material generik (`Icons.menu_book_rounded`) sehingga
/// logonya berbeda dari web.
///
/// SVG sumber digambar dengan `stroke="#000000"`, lalu diwarnai ulang di sini
/// memakai [ColorFilter] sehingga satu berkas aset dapat dipakai untuk warna
/// apa pun. `stroke-opacity` pada SVG tetap dipertahankan sebagai alpha,
/// sehingga goresan bertingkat pada "halaman buku" tetap terlihat.
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
