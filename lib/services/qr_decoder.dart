import 'dart:typed_data';

import 'package:flutter_zxing/flutter_zxing.dart' as zx;

/// Dekoder QR berbasis ZXing (Dart FFI, mendukung Windows).
///
/// Frame dari webcam (`camera_desktop`) berbentuk BGRA8888. Setiap baris bisa
/// memiliki padding (`bytesPerRow > width * 4`), sehingga buffer dirapikan dulu
/// sebelum diserahkan ke dekoder.
class QrDecoder {
  QrDecoder()
    : _params = zx.DecodeParams(
        imageFormat: zx.ImageFormat.bgra,
        format: zx.Format.qrCode,
        tryHarder: true,
        tryRotate: true,
        tryInverted: false,
        maxSize: 1280,
      );

  final zx.DecodeParams _params;

  /// Menghasilkan teks QR, atau `null` bila tidak ada QR yang terbaca.
  String? decodeBgra({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    if (width <= 0 || height <= 0 || bytes.isEmpty) {
      return null;
    }

    final rowLength = width * 4;
    final Uint8List packed;

    if (bytesPerRow == rowLength && bytes.length >= rowLength * height) {
      packed = bytes;
    } else {
      packed = Uint8List(rowLength * height);
      for (var row = 0; row < height; row++) {
        final srcOffset = row * bytesPerRow;
        if (srcOffset + rowLength > bytes.length) break;
        packed.setRange(
          row * rowLength,
          row * rowLength + rowLength,
          bytes,
          srcOffset,
        );
      }
    }

    try {
      final code = zx.zx.readBarcode(
        packed,
        _params.copyWith(width: width, height: height),
      );

      if (!code.isValid) return null;

      final text = code.text?.trim();
      if (text == null || text.isEmpty) return null;

      return text;
    } catch (_) {
      // Frame tidak dapat didekode — anggap tidak ada QR.
      return null;
    }
  }
}
