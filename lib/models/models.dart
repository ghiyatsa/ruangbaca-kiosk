/// Model data kiosk; bentuknya mengikuti respons API `/api/kiosk/*`.
///
/// Penamaan field mengikuti server apa adanya. Server mencampur snake_case dan
/// camelCase (`loan_max_books` di bootstrap, tapi `todayVisits`,
/// `coverImageUrl`, `hasEmail` di tempat lain), jadi model menyalin persis
/// tanpa menormalkan.
library;

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _asStringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String _asString(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;

DateTime? _asDateOrNull(dynamic value) {
  final text = _asStringOrNull(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

/// Konfigurasi sesi kiosk dari server: jam operasional.
class KioskSession {
  const KioskSession({
    required this.timezone,
    required this.operatingOpenTime,
    required this.operatingCloseTime,
    required this.withinOperatingHours,
    this.persistentForDevelopment = false,
    this.sessionExpiresAtIso,
  });

  final String timezone;
  final String operatingOpenTime;
  final String operatingCloseTime;
  final bool withinOperatingHours;
  final bool persistentForDevelopment;
  final String? sessionExpiresAtIso;

  factory KioskSession.fromJson(Map<String, dynamic> json) {
    return KioskSession(
      timezone: _asString(json['timezone'], 'Asia/Jakarta'),
      operatingOpenTime: _asString(json['operatingOpenTime'], '07:00'),
      operatingCloseTime: _asString(json['operatingCloseTime'], '21:00'),
      withinOperatingHours: json['withinOperatingHours'] == true,
      persistentForDevelopment: json['persistentForDevelopment'] == true,
      sessionExpiresAtIso: _asStringOrNull(json['sessionExpiresAtIso']),
    );
  }

  static const KioskSession unknown = KioskSession(
    timezone: 'Asia/Jakarta',
    operatingOpenTime: '--:--',
    operatingCloseTime: '--:--',
    withinOperatingHours: true,
  );
}

/// Statistik hari ini untuk layar utama.
class KioskStats {
  const KioskStats({
    this.deviceId = 'KIOSK-01',
    this.ipAddress = '',
    this.todayVisits = 0,
    this.todayBorrowed = 0,
    this.todayReturned = 0,
  });

  final String deviceId;
  final String ipAddress;
  final int todayVisits;
  final int todayBorrowed;
  final int todayReturned;

  factory KioskStats.fromJson(Map<String, dynamic> json) {
    return KioskStats(
      deviceId: _asString(json['deviceId'], 'KIOSK-01'),
      ipAddress: _asString(json['ipAddress']),
      todayVisits: _asInt(json['todayVisits']),
      todayBorrowed: _asInt(json['todayBorrowed']),
      todayReturned: _asInt(json['todayReturned']),
    );
  }
}

/// Satu opsi dropdown (value + label) dari server.
class SelectOption {
  const SelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Data awal aplikasi dari `GET /api/kiosk/bootstrap`.
class BootstrapData {
  const BootstrapData({
    required this.loanMaxBooks,
    required this.visitorTypeOptions,
    required this.purposeOptions,
    required this.session,
    required this.stats,
  });

  final int loanMaxBooks;
  final List<SelectOption> visitorTypeOptions;
  final List<SelectOption> purposeOptions;
  final KioskSession session;
  final KioskStats stats;

  static List<SelectOption> _options(dynamic raw) {
    if (raw is Map) {
      return raw.entries
          .map(
            (entry) => SelectOption(
              value: entry.key.toString(),
              label: entry.value?.toString() ?? entry.key.toString(),
            ),
          )
          .toList(growable: false);
    }
    return const <SelectOption>[];
  }

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    return BootstrapData(
      loanMaxBooks: _asInt(json['loan_max_books'], 3).clamp(1, 20),
      visitorTypeOptions: _options(json['visitor_type_options']),
      purposeOptions: _options(json['purpose_options']),
      session: KioskSession.fromJson(
        (json['session'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      stats: KioskStats.fromJson(
        (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

/// Buku hasil pencarian (`GET /api/kiosk/books/search`).
///
/// Bentuknya mengikuti `BookResource` di server.
class KioskBook {
  const KioskBook({
    required this.id,
    required this.title,
    this.subtitle,
    this.slug,
    this.isbn,
    this.issn,
    this.coverImageUrl,
    this.authors = const <String>[],
    this.itemsCount = 0,
    this.availableItemsCount = 0,
    this.isBorrowable = true,
    this.isAvailable = false,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String? slug;
  final String? isbn;
  final String? issn;
  final String? coverImageUrl;
  final List<String> authors;
  final int itemsCount;
  final int availableItemsCount;
  final bool isBorrowable;
  final bool isAvailable;

  String get authorsLabel =>
      authors.isEmpty ? 'Penulis belum tersedia' : authors.join(', ');

  String get identifierLabel {
    if (isbn != null && isbn!.isNotEmpty) return 'ISBN $isbn';
    if (issn != null && issn!.isNotEmpty) return 'ISSN $issn';
    return 'Tanpa ISBN/ISSN';
  }

  factory KioskBook.fromJson(Map<String, dynamic> json) {
    final rawAuthors = json['authors'];
    final authors = <String>[];
    if (rawAuthors is List) {
      for (final item in rawAuthors) {
        if (item is Map) {
          final name = _asStringOrNull(item['name']);
          if (name != null) authors.add(name);
        } else if (item != null) {
          authors.add(item.toString());
        }
      }
    }

    return KioskBook(
      id: _asInt(json['id']),
      title: _asString(json['title'], 'Tanpa judul'),
      subtitle: _asStringOrNull(json['subtitle']),
      slug: _asStringOrNull(json['slug']),
      isbn: _asStringOrNull(json['isbn']),
      issn: _asStringOrNull(json['issn']),
      coverImageUrl: _asStringOrNull(json['coverImageUrl']),
      authors: authors,
      itemsCount: _asInt(json['itemsCount']),
      availableItemsCount: _asInt(json['availableItemsCount']),
      isBorrowable: json['isBorrowable'] != false,
      isAvailable: json['isAvailable'] == true,
    );
  }
}

/// Anggota (hasil pencarian ringkas, tanpa email penuh).
class KioskMemberPreview {
  const KioskMemberPreview({
    required this.name,
    this.hasEmail = false,
    this.emailDomain,
    this.whatsappMasked,
  });

  final String name;
  final bool hasEmail;
  final String? emailDomain;
  final String? whatsappMasked;

  factory KioskMemberPreview.fromJson(Map<String, dynamic> json) {
    return KioskMemberPreview(
      name: _asString(json['name']),
      hasEmail: json['hasEmail'] == true,
      emailDomain: _asStringOrNull(json['emailDomain']),
      whatsappMasked: _asStringOrNull(json['whatsappMasked']),
    );
  }
}

/// Kunjungan yang baru dicatat.
class VisitResult {
  const VisitResult({required this.id, required this.name, this.visitedAt});

  final int id;
  final String name;
  final DateTime? visitedAt;

  factory VisitResult.fromJson(Map<String, dynamic> json) {
    return VisitResult(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      visitedAt: _asDateOrNull(json['visited_at']),
    );
  }
}

/// Ringkasan peminjaman yang berhasil disimpan.
class LoanResult {
  const LoanResult({
    required this.id,
    required this.memberName,
    required this.booksCount,
    this.borrowedAt,
    this.dueAt,
    required this.message,
  });

  final int id;
  final String memberName;
  final int booksCount;
  final DateTime? borrowedAt;
  final DateTime? dueAt;
  final String message;

  factory LoanResult.fromJson(Map<String, dynamic> json) {
    final loan = (json['loan'] as Map?)?.cast<String, dynamic>() ?? const {};
    final member =
        (loan['member'] as Map?)?.cast<String, dynamic>() ?? const {};

    return LoanResult(
      id: _asInt(loan['id']),
      memberName: _asString(member['name']),
      booksCount: _asInt(loan['books_count']),
      borrowedAt: _asDateOrNull(loan['borrowed_at']),
      dueAt: _asDateOrNull(loan['due_at']),
      message: _asString(json['message']),
    );
  }
}

/// Ringkasan pengembalian.
class ReturnResult {
  const ReturnResult({
    required this.returnedCount,
    required this.memberName,
    this.memberId,
    required this.message,
  });

  final int returnedCount;
  final String memberName;
  final int? memberId;
  final String message;

  factory ReturnResult.fromJson(Map<String, dynamic> json) {
    final member =
        (json['member'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ReturnResult(
      returnedCount: _asInt(json['returned_count']),
      memberName: _asString(member['name']),
      memberId: member['id'] == null ? null : _asInt(member['id']),
      message: _asString(json['message']),
    );
  }
}

/// Status claim registrasi anggota.
enum MemberClaimStatus {
  pending,
  linked,
  claimed,
  expired,
  failed,
  unknown;

  static MemberClaimStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return MemberClaimStatus.pending;
      case 'linked':
        return MemberClaimStatus.linked;
      case 'claimed':
        return MemberClaimStatus.claimed;
      case 'expired':
        return MemberClaimStatus.expired;
      case 'failed':
        return MemberClaimStatus.failed;
      default:
        return MemberClaimStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case MemberClaimStatus.pending:
        return 'Menunggu scan';
      case MemberClaimStatus.linked:
        return 'Terhubung';
      case MemberClaimStatus.claimed:
        return 'Terhubung';
      case MemberClaimStatus.expired:
        return 'Kedaluwarsa';
      case MemberClaimStatus.failed:
        return 'Gagal';
      case MemberClaimStatus.unknown:
        return 'Tidak diketahui';
    }
  }

  bool get isCompleted =>
      this == MemberClaimStatus.linked || this == MemberClaimStatus.claimed;
}

/// Claim registrasi anggota (QR penautan akun Google).
class MemberClaim {
  const MemberClaim({
    required this.id,
    this.name = '',
    this.email = '',
    this.whatsapp = '',
    this.address = '',
    this.linkUrl,
    this.qrSvg,
    this.status = MemberClaimStatus.pending,
    this.expiresAt,
    this.claimedAt,
    this.lastErrorMessage,
    this.lastErrorAt,
    this.approvalPending = false,
  });

  final int id;
  final String name;
  final String email;
  final String whatsapp;
  final String address;
  final String? linkUrl;
  final String? qrSvg;
  final MemberClaimStatus status;
  final DateTime? expiresAt;
  final DateTime? claimedAt;
  final String? lastErrorMessage;
  final DateTime? lastErrorAt;
  final bool approvalPending;

  bool get hasQr => (qrSvg ?? '').trim().isNotEmpty;

  factory MemberClaim.fromJson(Map<String, dynamic> json) {
    return MemberClaim(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      email: _asString(json['email']),
      whatsapp: _asString(json['whatsapp']),
      address: _asString(json['address']),
      linkUrl: _asStringOrNull(json['linkUrl']),
      qrSvg: _asStringOrNull(json['qrSvg']),
      status: MemberClaimStatus.parse(json['status']?.toString()),
      expiresAt: _asDateOrNull(json['expiresAt']),
      claimedAt: _asDateOrNull(json['claimedAt']),
      lastErrorMessage: _asStringOrNull(json['lastErrorMessage']),
      lastErrorAt: _asDateOrNull(json['lastErrorAt']),
      approvalPending: json['approvalPending'] == true,
    );
  }

  /// Status ringkas dari `GET /api/kiosk/members/status`.
  factory MemberClaim.fromStatusJson(Map<String, dynamic> json) {
    return MemberClaim(
      id: _asInt(json['id']),
      status: MemberClaimStatus.parse(json['status']?.toString()),
      approvalPending: json['approval_pending'] == true,
      lastErrorMessage: _asStringOrNull(json['last_error_message']),
    );
  }
}
