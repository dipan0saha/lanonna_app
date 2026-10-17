import 'api_error_code.dart';

/// A failed API call.
///
/// [message] is diagnostic text for logs and tests (the error code, an HTTP
/// status summary, or the server's English `detail.message`). It is never
/// shown to users: `apiErrorMessage` maps [code] to localized copy.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  final String message;
  final int? statusCode;

  /// Parsed JSON `detail` (`{error, message, params?, …}`).
  final Map<String, dynamic>? detail;

  /// Raw `detail.error` code, if the server sent one.
  String? get errorCode {
    final code = detail?['error'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// [errorCode] as a known [ApiErrorCode]; null when absent or unknown.
  ApiErrorCode? get code => ApiErrorCode.fromApi(errorCode);

  /// `detail.params` for codes whose copy takes values (e.g. a max length).
  Map<String, dynamic> get params {
    final raw = detail?['params'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  @override
  String toString() => message;
}
