import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'api_error_code.dart';
import 'api_exception.dart';

typedef IdTokenProvider = Future<String?> Function();
typedef AppCheckTokenProvider = Future<String?> Function();

/// Invoked when the API rejects the session (e.g. deleted account, NFR-DATA-001).
typedef ApiSessionInvalidatedHandler =
    Future<void> Function(ApiException exception);

/// Invoked when baby membership was ended (removed or left) while the app is open.
typedef ApiMembershipEndedHandler =
    Future<void> Function(ApiException exception);

/// How long one token read or HTTP call may run before [TimeoutException].
const Duration apiRequestTimeout = Duration(seconds: 20);

class ApiClient {
  ApiClient({
    required IdTokenProvider idTokenProvider,
    AppCheckTokenProvider? appCheckTokenProvider,
    ApiSessionInvalidatedHandler? onSessionInvalidated,
    http.Client? httpClient,
    Duration? timeout,
    bool Function()? isOffline,
  }) : _idTokenProvider = idTokenProvider,
       _appCheckTokenProvider = appCheckTokenProvider,
       _onSessionInvalidated = onSessionInvalidated,
       _http = httpClient ?? http.Client(),
       _timeout = timeout ?? apiRequestTimeout,
       _isOffline = isOffline;

  final IdTokenProvider _idTokenProvider;
  final AppCheckTokenProvider? _appCheckTokenProvider;
  final ApiSessionInvalidatedHandler? _onSessionInvalidated;
  ApiMembershipEndedHandler? _onMembershipEnded;
  final http.Client _http;
  final Duration _timeout;
  final bool Function()? _isOffline;

  ApiException get _offlineException =>
      _clientFailure(ApiErrorCode.networkUnavailable);

  /// A failure that never reached the API, coded like a server error.
  static ApiException _clientFailure(ApiErrorCode code) =>
      ApiException(code.apiValue, detail: {'error': code.apiValue});

  void _throwIfOffline() {
    if (_isOffline?.call() == true) {
      throw _offlineException;
    }
  }

  void registerMembershipEndedHandler(ApiMembershipEndedHandler handler) {
    _onMembershipEnded = handler;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _authorizedRequest('GET', path);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> getJsonPublic(
    String path, {
    Duration? timeout,
  }) async {
    final response = await _publicRequest('GET', path, timeout: timeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _authorizedRequest('POST', path, body: body);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _authorizedRequest('PATCH', path, body: body);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _authorizedRequest('PUT', path, body: body);
    return _decodeObject(response);
  }

  Future<void> deleteJson(String path, {Map<String, dynamic>? body}) async {
    // Non-2xx responses already throw in [_authorizedRequest].
    await _authorizedRequest('DELETE', path, body: body);
  }

  Future<http.Response> _publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    _throwIfOffline();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = {'Content-Type': 'application/json'};
    final requestTimeout = timeout ?? _timeout;
    try {
      final response = await switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        _ => throw UnsupportedError('HTTP method $method'),
      }.timeout(requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw _apiExceptionFromResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw _offlineException;
    } on TimeoutException {
      throw _clientFailure(ApiErrorCode.networkTimeout);
    } on http.ClientException {
      throw _offlineException;
    } on HandshakeException {
      throw _offlineException;
    }
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    _throwIfOffline();
    try {
      final token = await _idTokenProvider().timeout(_timeout);
      if (token == null || token.isEmpty) {
        throw ApiException('not_signed_in');
      }
      var uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final appCheckFuture = _appCheckTokenProvider?.call();
      final appCheck = appCheckFuture == null
          ? null
          : await appCheckFuture.timeout(_timeout);
      if (appCheck != null && appCheck.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheck;
      }
      final response = await switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PATCH' => _http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PUT' => _http.put(uri, headers: headers, body: jsonEncode(body ?? {})),
        'DELETE' => _http.delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        _ => throw UnsupportedError('HTTP method $method'),
      }.timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      return await _failAuthorizedResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw _offlineException;
    } on TimeoutException {
      throw _clientFailure(ApiErrorCode.networkTimeout);
    } on http.ClientException {
      throw _offlineException;
    } on HandshakeException {
      throw _offlineException;
    }
  }

  Future<http.Response> _failAuthorizedResponse(http.Response response) async {
    final exception = _apiExceptionFromResponse(response);
    if (exception.statusCode == 401 &&
        exception.code == ApiErrorCode.userDeleted &&
        _onSessionInvalidated != null) {
      await _onSessionInvalidated(exception);
    }
    if (exception.statusCode == 403 &&
        exception.code == ApiErrorCode.membershipEnded &&
        _onMembershipEnded != null) {
      await _onMembershipEnded!(exception);
    }
    throw exception;
  }

  ApiException _apiExceptionFromResponse(http.Response response) {
    var message = 'http_${response.statusCode}';
    Map<String, dynamic>? detail;
    try {
      final decoded = jsonDecode(response.body);
      final raw = decoded is Map ? decoded['detail'] : null;
      if (raw is Map) {
        detail = Map<String, dynamic>.from(raw);
        final code = detail['error'];
        if (code is String && code.isNotEmpty) message = code;
      }
    } catch (e, st) {
      debugPrint('api_client_error_body_parse_failed: $e\n$st');
    }
    return ApiException(
      message,
      statusCode: response.statusCode,
      detail: detail,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('unexpected_response_shape');
  }
}
