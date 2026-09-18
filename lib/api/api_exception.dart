/// Kesalahan API kiosk yang membawa pesan siap tampil.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.errors = const <String, List<String>>{},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isRateLimited => statusCode == 429;
  bool get isValidation => statusCode == 422;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Pesan validasi pertama bila ada; lebih informatif untuk pengguna.
  String get bestMessage {
    for (final entry in errors.entries) {
      if (entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return message;
  }

  /// Pesan untuk field tertentu, jika tersedia.
  String? fieldError(String field) {
    final values = errors[field];
    if (values != null && values.isNotEmpty) {
      return values.first;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $bestMessage';
}
