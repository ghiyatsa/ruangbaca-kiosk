import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/models.dart';
import 'api_exception.dart';

/// Klien HTTP untuk API kiosk Laravel (`/api/kiosk/*`).
///
/// Autentikasi memakai header `X-Kiosk-Api-Key` (utama) dan/atau
/// `X-Kiosk-Device-Token`. Keduanya dikirim bila tersedia sehingga server
/// memilih kredensial yang valid.
class KioskApi {
  KioskApi({required this.config, http.Client? client})
    : _client = client ?? http.Client() {
    // Device token opsional dari konfigurasi (untuk polling status pendaftaran).
    _deviceToken = config.deviceToken;
  }

  final AppConfig config;
  final http.Client _client;

  /// Device token opsional (bila dikonfigurasi).
  String? _deviceToken;

  String get baseUrl => config.baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${config.baseUrl}/$cleaned',
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (config.hasApiKey) {
      headers['X-Kiosk-Api-Key'] = config.apiKey;
    }
    final token = _deviceToken;
    if (token != null && token.isNotEmpty) {
      headers['X-Kiosk-Device-Token'] = token;
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Inti request
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) async {
    final uri = _uri(path, query);
    final headers = {..._headers(json: body != null), ...?extraHeaders};
    final effectiveTimeout =
        timeout ?? Duration(seconds: config.requestTimeoutSeconds);

    try {
      late http.Response response;
      final encodedBody = body == null ? null : jsonEncode(body);

      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(effectiveTimeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encodedBody)
              .timeout(effectiveTimeout);
          break;
        default:
          throw ArgumentError('Metode tidak didukung: $method');
      }

      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Server tidak merespons. Periksa koneksi jaringan kiosk.',
      );
    } on SocketException {
      throw ApiException(
        'Tidak dapat terhubung ke server (${config.baseUrl}). '
        'Pastikan jaringan perpustakaan aktif.',
      );
    } on http.ClientException catch (error) {
      throw ApiException('Gangguan koneksi: ${error.message}');
    } on FormatException {
      throw ApiException('Respons server tidak dapat dibaca.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    final raw = response.body.trim();

    Map<String, dynamic> payload = <String, dynamic>{};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else {
          payload = <String, dynamic>{'data': decoded};
        }
      } on FormatException {
        if (status >= 400) {
          throw ApiException(
            'Server mengembalikan galat ($status).',
            statusCode: status,
          );
        }
        throw ApiException('Respons server tidak dapat dibaca.');
      }
    }

    if (status >= 200 && status < 300) {
      return payload;
    }

    throw _toApiException(status, payload);
  }

  ApiException _toApiException(int status, Map<String, dynamic> payload) {
    final errors = <String, List<String>>{};
    final rawErrors = payload['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) {
        if (value is List) {
          errors[key.toString()] = value
              .map((item) => item.toString())
              .toList(growable: false);
        } else if (value != null) {
          errors[key.toString()] = <String>[value.toString()];
        }
      });
    }

    final message = switch (status) {
      401 =>
        payload['message']?.toString() ??
            'Perangkat kiosk tidak terautentikasi.',
      403 =>
        payload['message']?.toString() ??
            'Akses kiosk hanya diizinkan dari jaringan internal perpustakaan.',
      429 =>
        payload['message']?.toString() ??
            'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
      503 =>
        payload['message']?.toString() ??
            'Layanan kiosk sedang tidak tersedia.',
      _ =>
        payload['message']?.toString() ??
            (status == 422
                ? 'Data yang diberikan tidak valid.'
                : 'Terjadi kesalahan ($status).'),
    };

    return ApiException(message, statusCode: status, errors: errors);
  }

  // ---------------------------------------------------------------------------
  // Endpoint
  // ---------------------------------------------------------------------------

  /// Data awal aplikasi (jam operasional, opsi form, batas pinjam, statistik).
  Future<BootstrapData> bootstrap() async {
    final json = await _send('GET', 'api/kiosk/bootstrap');
    return BootstrapData.fromJson(json);
  }

  /// Catat kunjungan perpustakaan.
  Future<VisitResult> storeVisit({
    required String name,
    required String visitorType,
    required String purpose,
    String? identityNumber,
    String? institution,
    String? phone,
    String? notes,
  }) async {
    final json = await _send(
      'POST',
      'api/kiosk/visits',
      body: {
        'name': name,
        'visitor_type': visitorType,
        'purpose': purpose,
        if (identityNumber != null && identityNumber.isNotEmpty)
          'identity_number': identityNumber,
        if (institution != null && institution.isNotEmpty)
          'institution': institution,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return VisitResult.fromJson(
      (json['visit'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Cari buku.
  ///
  /// - `mode = borrow`: kata kunci bebas.
  /// - `mode = return`: wajib menyertakan `memberIdentifier`; mengembalikan
  ///   buku yang sedang dipinjam anggota tersebut.
  Future<List<KioskBook>> searchBooks({
    String query = '',
    String mode = 'borrow',
    String? memberIdentifier,
  }) async {
    final json = await _send(
      'GET',
      'api/kiosk/books/search',
      query: {
        'q': query,
        'mode': mode,
        if (memberIdentifier != null && memberIdentifier.isNotEmpty)
          'member_identifier': memberIdentifier,
      },
    );
    final raw = json['books'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => KioskBook.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const <KioskBook>[];
  }

  /// Pinjam buku via QR verifikasi anggota.
  Future<LoanResult> borrow({
    required String verificationPayload,
    required String memberIdentifier,
    required List<int> bookIds,
    String? idempotencyKey,
  }) async {
    final json = await _send(
      'POST',
      'api/kiosk/loans/borrow',
      body: {
        'verification_payload': verificationPayload,
        'member_identifier': memberIdentifier,
        'book_ids': bookIds,
      },
      extraHeaders: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return LoanResult.fromJson(json);
  }

  /// Kembalikan buku via QR verifikasi anggota.
  Future<ReturnResult> returnBooks({
    required String verificationPayload,
    required String memberIdentifier,
    required List<int> bookIds,
    String? idempotencyKey,
  }) async {
    final json = await _send(
      'POST',
      'api/kiosk/loans/return',
      body: {
        'verification_payload': verificationPayload,
        'member_identifier': memberIdentifier,
        'book_ids': bookIds,
      },
      extraHeaders: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return ReturnResult.fromJson(json);
  }

  /// Registrasi anggota baru → dapat QR penautan akun Google.
  Future<MemberClaim> storeMember({
    required String name,
    required String email,
    required String whatsapp,
    required String address,
  }) async {
    final json = await _send(
      'POST',
      'api/kiosk/members',
      body: {
        'name': name,
        'email': email,
        'whatsapp': whatsapp,
        'address': address,
      },
    );
    return MemberClaim.fromJson(
      (json['claim'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Status claim registrasi perangkat ini (untuk polling).
  Future<MemberClaim?> memberRegistrationStatus() async {
    final json = await _send('GET', 'api/kiosk/members/status');
    final claim = json['claim'];
    if (claim is Map) {
      return MemberClaim.fromStatusJson(claim.cast<String, dynamic>());
    }
    return null;
  }

  /// Batalkan claim registrasi aktif perangkat ini.
  Future<void> cancelMemberRegistration() async {
    await _send('POST', 'api/kiosk/members/cancel', body: const {});
  }

  /// Cari anggota berdasarkan NIM / email / nomor HP.
  Future<KioskMemberPreview?> findMember(String identifier) async {
    final json = await _send(
      'GET',
      'api/kiosk/members/find',
      query: {'identifier': identifier},
    );
    final member = json['member'];
    if (member is Map) {
      return KioskMemberPreview.fromJson(member.cast<String, dynamic>());
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}
