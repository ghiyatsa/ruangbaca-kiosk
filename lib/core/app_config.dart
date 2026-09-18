import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Konfigurasi aplikasi kiosk.
///
/// Prioritas (tertinggi → terendah):
///   1. Variabel lingkungan (KIOSK_BASE_URL, KIOSK_API_KEY, ...)
///   2. `config/kiosk.json` (atau `kiosk.json`) di samping executable
///   3. `assets/kiosk.json` (nilai bawaan saat dibangun)
///
/// Dengan begitu teknis dapat mengubah alamat server / API key tanpa membangun
/// ulang aplikasi — cukup edit file di samping executable lalu jalankan ulang.
///
/// Autentikasi memakai **API key** (`X-Kiosk-Api-Key`) yang bersifat permanen,
/// sehingga kiosk tidak perlu PIN maupun aktivasi perangkat.
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.apiKey,
    this.deviceToken,
    required this.deviceName,
    this.idleTimeoutSeconds = 90,
    this.kioskMode = true,
    this.enableWebcamScanner = true,
    this.requestTimeoutSeconds = 25,
  });

  /// Contoh: `https://ruangbaca.example.com` (tanpa garis miring di akhir).
  final String baseUrl;

  /// API key bersama (`X-Kiosk-Api-Key`) hasil `php artisan kiosk:api-key generate`.
  final String apiKey;

  /// Device token opsional (`X-Kiosk-Device-Token`).
  ///
  /// Hanya diperlukan agar kiosk dapat memantau status penautan akun Google
  /// secara langsung (`GET /api/kiosk/members/status`). Endpoint tersebut
  /// membaca perangkat dari device token, bukan API key. Bila kosong,
  /// pendaftaran tetap berjalan normal — hanya statusnya tidak dapat dipantau.
  final String? deviceToken;

  /// Nama perangkat yang tampil pada dashboard admin.
  final String deviceName;

  /// Kembali ke layar utama setelah sekian detik tanpa aktivitas.
  final int idleTimeoutSeconds;

  /// Mode kiosk: layar penuh, selalu di atas, cegah tombol tutup.
  final bool kioskMode;

  /// Aktifkan pemindai QR via webcam (di samping scanner HID/USB).
  final bool enableWebcamScanner;

  final int requestTimeoutSeconds;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get hasDeviceToken => (deviceToken ?? '').trim().isNotEmpty;

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    String str(String key, [String fallback = '']) {
      final value = map[key];
      return value == null ? fallback : value.toString();
    }

    int asInt(String key, int fallback) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool asBool(String key, bool fallback) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    String normalizedBaseUrl(String raw) {
      var value = raw.trim();
      if (value.isEmpty) return 'http://localhost:8000';
      while (value.endsWith('/')) {
        value = value.substring(0, value.length - 1);
      }
      return value;
    }

    final deviceToken = str('deviceToken').trim();

    return AppConfig(
      baseUrl: normalizedBaseUrl(str('baseUrl', 'http://localhost:8000')),
      apiKey: str('apiKey').trim(),
      deviceToken: deviceToken.isEmpty ? null : deviceToken,
      deviceName: str('deviceName', 'Kiosk Ruang Baca').trim(),
      idleTimeoutSeconds: asInt('idleTimeoutSeconds', 90).clamp(15, 3600),
      kioskMode: asBool('kioskMode', true),
      enableWebcamScanner: asBool('enableWebcamScanner', true),
      requestTimeoutSeconds: asInt('requestTimeoutSeconds', 25).clamp(5, 120),
    );
  }

  AppConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? deviceToken,
    String? deviceName,
    int? idleTimeoutSeconds,
    bool? kioskMode,
    bool? enableWebcamScanner,
    int? requestTimeoutSeconds,
  }) {
    return AppConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceName: deviceName ?? this.deviceName,
      idleTimeoutSeconds: idleTimeoutSeconds ?? this.idleTimeoutSeconds,
      kioskMode: kioskMode ?? this.kioskMode,
      enableWebcamScanner: enableWebcamScanner ?? this.enableWebcamScanner,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
    );
  }

  /// Lokasi berkas konfigurasi eksternal yang dibaca aplikasi.
  static String externalConfigPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}config'
        '${Platform.pathSeparator}kiosk.json';
  }

  static Future<AppConfig> load() async {
    final env = Platform.environment;

    final envMap = <String, dynamic>{};
    void takeEnv(String envKey, String configKey) {
      final value = env[envKey];
      if (value != null && value.trim().isNotEmpty) {
        envMap[configKey] = value;
      }
    }

    takeEnv('KIOSK_BASE_URL', 'baseUrl');
    takeEnv('KIOSK_API_KEY', 'apiKey');
    takeEnv('KIOSK_DEVICE_TOKEN', 'deviceToken');
    takeEnv('KIOSK_DEVICE_NAME', 'deviceName');

    final fileMap = await _readExternalConfig();
    final assetMap = await _readAssetConfig();

    final merged = <String, dynamic>{...assetMap, ...fileMap, ...envMap};
    return AppConfig.fromMap(merged);
  }

  static Future<Map<String, dynamic>> _readExternalConfig() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = <String>[
        '$exeDir${Platform.pathSeparator}config'
            '${Platform.pathSeparator}kiosk.json',
        '$exeDir${Platform.pathSeparator}kiosk.json',
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (file.existsSync()) {
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      }
    } catch (_) {
      // Abaikan: konfigurasi eksternal bersifat opsional.
    }

    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _readAssetConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/kiosk.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Abaikan: aset bawaan mungkin belum ada.
    }

    return <String, dynamic>{};
  }
}
