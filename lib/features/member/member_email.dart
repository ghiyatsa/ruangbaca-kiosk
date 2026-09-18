import '../../models/models.dart';

/// Domain email kampus yang diizinkan (selaras dengan web).
const List<String> allowedEmailDomains = <String>[
  'mhs.unimal.ac.id',
  'unimal.ac.id',
];

const String defaultEmailDomain = 'mhs.unimal.ac.id';

/// Memisahkan email menjadi bagian lokal dan domain (tanpa `@`).
({String localPart, String domain}) splitMemberEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return (localPart: '', domain: defaultEmailDomain);
  }

  final atIndex = trimmed.indexOf('@');
  if (atIndex == -1) {
    return (localPart: trimmed, domain: defaultEmailDomain);
  }

  final localPart = trimmed.substring(0, atIndex);
  final domain = trimmed.substring(atIndex + 1);
  return (
    localPart: localPart,
    domain: domain.isEmpty ? defaultEmailDomain : domain,
  );
}

/// Menggabungkan bagian lokal dan domain menjadi email lengkap.
String composeMemberEmail(String localPart, String domain) {
  final local = localPart.trim().toLowerCase();
  final cleanDomain = domain.trim().toLowerCase().replaceAll(
    RegExp(r'^@+'),
    '',
  );

  if (local.isEmpty && cleanDomain.isEmpty) return '';
  return '$local@$cleanDomain';
}

/// Validasi email anggota; mengembalikan pesan galat atau `null`.
String? validateMemberEmail(String localPart, String domain) {
  final local = localPart.trim();
  final cleanDomain = domain.trim().toLowerCase().replaceAll(
    RegExp(r'^@+'),
    '',
  );

  if (local.isEmpty && cleanDomain.isEmpty) {
    return 'Email wajib diisi.';
  }

  if (local.isEmpty) {
    return 'Masukkan bagian email sebelum tanda @.';
  }

  if (!allowedEmailDomains.contains(cleanDomain)) {
    return 'Gunakan email UNIMAL dengan domain @mhs.unimal.ac.id '
        'atau @unimal.ac.id.';
  }

  return null;
}

/// Apakah claim masih dalam proses (bukan selesai).
bool isInteractiveClaim(MemberClaim? claim) {
  if (claim == null) return false;
  return !claim.status.isCompleted;
}
