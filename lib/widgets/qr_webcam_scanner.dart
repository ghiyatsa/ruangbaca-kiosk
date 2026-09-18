import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/qr_decoder.dart';

/// Pemindai QR via webcam.
///
/// Menampilkan pratinjau kamera dan mendekode QR dari aliran frame memakai
/// ZXing (FFI). Setelah satu QR terbaca, pemindaian dihentikan dan
/// [onDetected] dipanggil sekali.
class QrWebcamScanner extends StatefulWidget {
  const QrWebcamScanner({
    super.key,
    required this.onDetected,
    this.active = true,
    this.overlayHint = 'Arahkan QR ke kamera',
  });

  final ValueChanged<String> onDetected;

  /// Bila `false`, kamera tidak dijalankan (hemat resource).
  final bool active;

  final String overlayHint;

  @override
  State<QrWebcamScanner> createState() => _QrWebcamScannerState();
}

class _QrWebcamScannerState extends State<QrWebcamScanner> {
  final QrDecoder _decoder = QrDecoder();

  CameraController? _controller;
  bool _initializing = false;
  bool _streaming = false;
  bool _detected = false;
  String? _error;

  /// Throttle dekode agar UI tetap responsif.
  static const Duration _decodeInterval = Duration(milliseconds: 280);
  DateTime _lastDecodeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_start());
    }
  }

  @override
  void didUpdateWidget(covariant QrWebcamScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      unawaited(_start());
    } else if (!widget.active && oldWidget.active) {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (_initializing || _streaming) return;

    setState(() {
      _initializing = true;
      _error = null;
      _detected = false;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Tidak ada kamera yang terdeteksi.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.startImageStream(_onFrame);

      setState(() {
        _controller = controller;
        _streaming = true;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _streaming = false;
        _error = 'Kamera tidak dapat diaktifkan: $error';
      });
    }
  }

  Future<void> _stop() async {
    final controller = _controller;
    _controller = null;
    _streaming = false;

    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {
        // Abaikan.
      }
      try {
        await controller.dispose();
      } catch (_) {
        // Abaikan.
      }
    }

    if (mounted) setState(() {});
  }

  void _onFrame(CameraImage image) {
    if (_detected || !widget.active) return;

    final now = DateTime.now();
    if (now.difference(_lastDecodeAt) < _decodeInterval) return;
    _lastDecodeAt = now;

    final plane = image.planes.isEmpty ? null : image.planes.first;
    if (plane == null) return;

    final text = _decoder.decodeBgra(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
    );

    if (text == null || text.isEmpty) return;

    _detected = true;
    unawaited(_stop());
    widget.onDetected(text);
  }

  Future<void> _retry() async {
    await _stop();
    await _start();
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_error != null) {
      return _ScannerMessage(
        icon: Icons.videocam_off_outlined,
        title: 'Kamera tidak tersedia',
        message: _error!,
        onRetry: _retry,
      );
    }

    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const _ScannerMessage(
        icon: Icons.videocam_outlined,
        title: 'Menyiapkan kamera...',
        message: 'Mohon tunggu sebentar.',
        loading: true,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 480,
            height: controller.value.previewSize?.width ?? 640,
            child: CameraPreview(controller),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.overlayHint,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              Icon(icon, size: 44, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
