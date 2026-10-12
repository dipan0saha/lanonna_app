import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';

class _HangingClient extends http.BaseClient {
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends += 1;
    return Completer<http.StreamedResponse>().future;
  }
}

void main() {
  test('a hung request becomes network_timeout', () async {
    final httpClient = _HangingClient();
    final api = ApiClient(
      idTokenProvider: () async => 'token',
      httpClient: httpClient,
      timeout: const Duration(milliseconds: 30),
    );

    expect(
      () => api.getJson('/v1/babies'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.detail?['error'],
          'code',
          'network_timeout',
        ),
      ),
    );
  });

  test('a known-offline device fails before the socket opens', () async {
    final httpClient = _HangingClient();
    final api = ApiClient(
      idTokenProvider: () async => 'token',
      httpClient: httpClient,
      isOffline: () => true,
      timeout: const Duration(seconds: 30),
    );

    expect(
      () => api.getJson('/v1/babies'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.detail?['error'],
          'code',
          'network_unavailable',
        ),
      ),
    );
    expect(httpClient.sends, 0);
  });

  test('a hung ID token becomes network_timeout', () async {
    final api = ApiClient(
      idTokenProvider: () => Completer<String?>().future,
      timeout: const Duration(milliseconds: 30),
    );

    expect(
      () => api.getJson('/v1/onboarding/status'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.detail?['error'],
          'code',
          'network_timeout',
        ),
      ),
    );
  });
}
