class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  /// Parsed JSON `detail` when the API returns a structured error body.
  final Map<String, dynamic>? detail;

  @override
  String toString() => message;
}
