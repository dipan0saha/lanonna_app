import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/display_photo_upload.dart';

/// #415: a provider photo is copied into our bucket best effort; a failure
/// never throws, so finishing the profile is never blocked by it.
void main() {
  final upload = DisplayPhotoUpload(ApiClient(idTokenProvider: () async => null));

  Future<String?> importWith(
    String url,
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      http.runWithClient(
        () => upload.importProfileAvatar(url, timeout: timeout),
        () => MockClient(handler),
      );

  test('download failure returns null', () async {
    expect(
      await importWith(
        'https://lh3.example.test/a.jpg',
        (_) async => http.Response('nope', 404),
      ),
      isNull,
    );
  });

  test('network error returns null', () async {
    expect(
      await importWith(
        'https://lh3.example.test/a.jpg',
        (_) async => throw http.ClientException('reset'),
      ),
      isNull,
    );
  });

  test('empty or undecodable body returns null', () async {
    expect(
      await importWith(
        'https://lh3.example.test/a.jpg',
        (_) async => http.Response('', 200),
      ),
      isNull,
    );
    expect(
      await importWith(
        'https://lh3.example.test/a.jpg',
        (_) async => http.Response('not an image', 200),
      ),
      isNull,
    );
  });

  test('slow download times out to null', () async {
    expect(
      await importWith(
        'https://lh3.example.test/a.jpg',
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      ),
      isNull,
    );
  });

  test('non-https source is never fetched', () async {
    var fetched = false;
    expect(
      await importWith('http://lh3.example.test/a.jpg', (_) async {
        fetched = true;
        return http.Response('x', 200);
      }),
      isNull,
    );
    expect(fetched, isFalse);
  });
}
