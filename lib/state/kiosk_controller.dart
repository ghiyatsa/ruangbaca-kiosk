import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

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

  /// Perangkat kiosk tidak dapat menjangkau server.
  error,
}

/// Kondisi koneksi kiosk ke server, dipantau berkala saat menganggur.
///
/// Dinamai `KioskConnectionState`, bukan `ConnectionState`, agar tidak bentrok
/// dengan enum bawaan Flutter untuk `FutureBuilder`.
enum KioskConnectionState {
  /// Hasil pantauan terakhir: server terjangkau.
  online,

  /// Hasil pantauan terakhir: server tidak terjangkau.
  offline,
}

/// State pusat aplikasi kiosk: data bootstrap, sesi, dan aksi yang memanggil
/// API. Widget membacanya lewat `provider`.
///
/// Autentikasi memakai API key permanen, jadi tidak ada alur aktivasi/PIN.
class KioskController extends ChangeNotifier {
  /// [api] hanya dipakai pengujian untuk menyuntikkan klien HTTP tiruan.
  /// [connectionCheckInterval] memperpendek jeda pantauan koneksi pada uji.
  KioskController({
    required AppConfig config,
    KioskApi? api,
    Duration? connectionCheckInterval,
  }) : _config = config,
       _connectionCheckInterval =
           connectionCheckInterval ?? const Duration(seconds: 15) {
    _api = api ?? KioskApi(config: config);
  }

  final AppConfig _config;
  late final KioskApi _api;
  final Duration _connectionCheckInterval;

  Timer? _connectionTimer;
  bool _checking = false;
  bool _disposed = false;

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

  KioskConnectionState _connection = KioskConnectionState.online;

  /// Hasil pantauan koneksi terakhir. Selama `online`, UI tidak menampilkan
  /// apa pun; begitu `offline`, banner peringatan muncul dan aksi tulis
  /// dinonaktifkan sampai koneksi pulih.
  KioskConnectionState get connection => _connection;

  bool get isOffline => _connection == KioskConnectionState.offline;

  // ---------------------------------------------------------------------------
  // Pantauan koneksi
  // ---------------------------------------------------------------------------

  /// Mulai memeriksa koneksi berkala selama aplikasi siap.
  ///
  /// Dipanggil otomatis setelah bootstrap pertama berhasil; aman dipanggil
  /// berulang (timer lama dibuang lebih dulu).
  void startConnectionWatch() {
    _connectionTimer?.cancel();
    _connection = KioskConnectionState.online;
    _connectionTimer = Timer.periodic(
      _connectionCheckInterval,
      (_) => unawaited(checkConnection()),
    );
  }

  /// Periksa koneksi sekali sekaligus menyegarkan data bootstrap.
  ///
  /// Memakai ulang endpoint `bootstrap` — bukan rute baru — supaya pemantauan
  /// langsung berfungsi di server yang sudah ter-deploy tanpa perlu perubahan
  /// server, dan statistik di layar utama ikut mutakhir.
  ///
  /// Kegagalan jaringan menandai kiosk offline; keberhasilan mengembalikannya
  /// online. Galat non-jaringan (mis. 401/403/404) TIDAK dianggap offline,
  /// karena server jelas menjawab — masalahnya ada di kredensial, bukan
  /// koneksi.
  Future<void> checkConnection() async {
    // Bila koneksi lambat, satu pemeriksaan bisa memakan waktu lebih lama
    // daripada jeda timer. Tanpa penjaga ini, pemeriksaan akan menumpuk dan
    // membebani server; cukup satu yang berjalan pada satu waktu.
    if (_checking || _disposed) return;
    _checking = true;

    bool reachable;
    try {
      final data = await _api.bootstrap();
      if (!_disposed) {
        _bootstrap = data;
      }
      reachable = true;
    } on ApiException catch (error) {
      reachable = !error.isConnectionError;
    } catch (_) {
      reachable = true;
    } finally {
      _checking = false;
    }

    if (_disposed) return;

    final next = reachable
        ? KioskConnectionState.online
        : KioskConnectionState.offline;
    if (next == _connection) {
      // Koneksi tidak berubah, tetapi statistik mungkin baru saja diperbarui.
      if (reachable) notifyListeners();
      return;
    }
    _connection = next;
    notifyListeners();
  }

  /// Hentikan pantauan koneksi (dipakai saat dispose).
  void stopConnectionWatch() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

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
      startConnectionWatch();
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
    _disposed = true;
    stopConnectionWatch();
    _api.dispose();
    super.dispose();
  }
}

/// Menjalankan future tanpa menunggu (menghindari lint `unawaited_futures`).
void unawaited(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}

/// Akses status koneksi kiosk dari widget.
extension KioskConnectionContext on BuildContext {
  /// Pantau status offline, dan bangun ulang widget HANYA saat status itu
  /// berubah — bukan setiap kali controller memberi tahu (mis. statistik
  /// tersegarkan tiap 15 detik).
  bool watchOffline() =>
      select<KioskController, bool>((controller) => controller.isOffline);
}
