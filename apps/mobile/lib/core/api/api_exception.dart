/// A failed API call.
///
/// [message] is diagnostic text for logs and tests (an error code, an HTTP
/// status summary). It is never shown to users: [apiErrorMessage] maps
/// [errorCode] to localized copy and otherwise falls back to [serverMessage]
/// or a localized generic message.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.detail,
    this.serverMessage,
  });

  final String message;
  final int? statusCode;

  /// Parsed JSON `detail` when the API returns a structured error body.
  final Map<String, dynamic>? detail;

  /// Human-readable copy the server returned for this failure, if any.
  final String? serverMessage;

  /// Machine-readable `detail.error` code, if the server sent one.
  String? get errorCode {
    final code = detail?['error'];
    return code is String && code.isNotEmpty ? code : null;
  }

  @override
  String toString() => message;
}
