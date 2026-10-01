import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'api_exception.dart';

typedef IdTokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({required IdTokenProvider idTokenProvider, http.Client? httpClient})
      : _idTokenProvider = idTokenProvider,
        _http = httpClient ?? http.Client();

  final IdTokenProvider _idTokenProvider;
  final http.Client _http;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _authorizedRequest('GET', path);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> getJsonPublic(String path) async {
    final response = await _publicRequest('GET', path);
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(String path) async {
    final response = await _authorizedRequest('GET', path);
    return _decodeList(response);
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

  Future<void> deleteJson(String path) async {
    final response = await _authorizedRequest('DELETE', path);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException('Delete failed (${response.statusCode})');
  }

  Future<Map<String, dynamic>> postJsonPublic(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _publicRequest('POST', path, body: body);
    return _decodeObject(response);
  }

  Future<http.Response> _publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = {'Content-Type': 'application/json'};
    final response = await switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
      _ => throw ApiException('Unsupported method $method'),
    };
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _idTokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException('Not signed in');
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = await switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
      'PATCH' => _http.patch(uri, headers: headers, body: jsonEncode(body ?? {})),
      'PUT' => _http.put(uri, headers: headers, body: jsonEncode(body ?? {})),
      'DELETE' => _http.delete(uri, headers: headers),
      _ => throw ApiException('Unsupported method $method'),
    };
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('Expected JSON object');
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    throw ApiException('Expected JSON list');
  }
}
