import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/kiosk_api.dart';
import '../core/app_config.dart';
import '../models/models.dart';

/// Status siap-pakai aplikasi.
enum KioskStatus {
  /// Sedang memuat konfigurasi & bootstrap.
  initializing,

  /// Siap melayani.
  ready,

  /// Gagal total (mis. API key salah atau server tidak dapat dihubungi).
  error,
}

/// State pusat aplikasi kiosk: data bootstrap, sesi, dan aksi yang memanggil
/// API. Widget membacanya lewat `provider`.
///
/// Autentikasi memakai API key permanen, jadi tidak ada alur aktivasi/PIN.
class KioskController extends ChangeNotifier {
  /// [api] hanya dipakai pengujian untuk menyuntikkan klien HTTP tiruan.
  KioskController({required AppConfig config, KioskApi? api})
    : _config = config {
    _api = api ?? KioskApi(config: config);
  }

  final AppConfig _config;
  late final KioskApi _api;

  AppConfig get config => _config;
  KioskApi get api => _api;

  KioskStatus _status = KioskStatus.initializing;
  KioskStatus get status => _status;

  String? _startupError;
  String? get startupError => _startupError;

  BootstrapData? _bootstrap;
  BootstrapData? get bootstrap => _bootstrap;

  KioskSession get session => _bootstrap?.session ?? KioskSession.unknown;
  KioskStats get stats => _bootstrap?.stats ?? const KioskStats();
  int get loanMaxBooks => _bootstrap?.loanMaxBooks ?? 3;
  List<SelectOption> get visitorTypeOptions =>
      _bootstrap?.visitorTypeOptions ?? const <SelectOption>[];
  List<SelectOption> get purposeOptions =>
      _bootstrap?.purposeOptions ?? const <SelectOption>[];

  bool get isReady => _status == KioskStatus.ready;
  bool get withinOperatingHours => session.withinOperatingHours;

  // ---------------------------------------------------------------------------
  // Inisialisasi
  // ---------------------------------------------------------------------------

  /// Ambil data bootstrap. API key sudah tersedia dari konfigurasi.
  Future<void> initialize() async {
    _status = KioskStatus.initializing;
    _startupError = null;
    notifyListeners();

    try {
      await _loadBootstrap();
    } on ApiException catch (error) {
      _status = KioskStatus.error;
      _startupError = error.bestMessage;
      notifyListeners();
    } catch (error) {
      _status = KioskStatus.error;
      _startupError = error.toString();
      notifyListeners();
    }
  }

  Future<void> _loadBootstrap() async {
    final data = await _api.bootstrap();
    _bootstrap = data;
    _status = KioskStatus.ready;
    notifyListeners();
  }

  /// Ambil ulang data bootstrap (statistik, jam operasional).
  Future<void> refreshBootstrap() => _loadBootstrap();

  // ---------------------------------------------------------------------------
  // Aksi layanan
  // ---------------------------------------------------------------------------

  Future<VisitResult> recordVisit({
    required String name,
    required String visitorType,
    required String purpose,
    String? identityNumber,
    String? institution,
    String? phone,
    String? notes,
  }) async {
    final result = await _api.storeVisit(
      name: name,
      visitorType: visitorType,
      purpose: purpose,
      identityNumber: identityNumber,
      institution: institution,
      phone: phone,
      notes: notes,
    );
    // Perbarui statistik tanpa memblokir alur sukses.
    unawaited(refreshBootstrapQuietly());
    return result;
  }

  /// Buku tamu cepat: catat kunjungan dari scan Member Key anggota.
  Future<VisitResult> recordMemberVisit({
    required String verificationPayload,
    String? purpose,
  }) async {
    final result = await _api.storeMemberVisit(
      verificationPayload: verificationPayload,
      purpose: purpose,
    );
    unawaited(refreshBootstrapQuietly());
    return result;
  }

  Future<KioskBookSearchResult> searchBooks({
    String query = '',
    String mode = 'borrow',
    String? memberIdentifier,
  }) {
    return _api.searchBooks(
      query: query,
      mode: mode,
      memberIdentifier: memberIdentifier,
    );
  }

  Future<LoanResult> borrowBooks({
    required String verificationPayload,
    required String memberIdentifier,
    required List<int> bookIds,
    String? idempotencyKey,
  }) async {
    final result = await _api.borrow(
      verificationPayload: verificationPayload,
      memberIdentifier: memberIdentifier,
      bookIds: bookIds,
      idempotencyKey: idempotencyKey,
    );
    unawaited(refreshBootstrapQuietly());
    return result;
  }

  Future<ReturnResult> returnBooks({
    required String verificationPayload,
    required String memberIdentifier,
    required List<int> bookIds,
    String? idempotencyKey,
  }) async {
    final result = await _api.returnBooks(
      verificationPayload: verificationPayload,
      memberIdentifier: memberIdentifier,
      bookIds: bookIds,
      idempotencyKey: idempotencyKey,
    );
    unawaited(refreshBootstrapQuietly());
    return result;
  }

  Future<MemberClaim> registerMember({
    required String name,
    required String email,
    required String whatsapp,
    required String address,
  }) {
    return _api.storeMember(
      name: name,
      email: email,
      whatsapp: whatsapp,
      address: address,
    );
  }

  Future<MemberClaim?> memberRegistrationStatus() =>
      _api.memberRegistrationStatus();

  Future<void> cancelMemberRegistration() => _api.cancelMemberRegistration();

  Future<KioskMemberPreview?> findMember(String identifier) =>
      _api.findMember(identifier);

  Future<void> refreshBootstrapQuietly() async {
    try {
      await _loadBootstrap();
    } catch (_) {
      // Diamkan: statistik bukan hal kritis.
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}

/// Menjalankan future tanpa menunggu (menghindari lint `unawaited_futures`).
void unawaited(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}
