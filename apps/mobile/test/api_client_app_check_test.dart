import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';

void main() {
  group('ApiClient and App Check', () {
    test('attaches the App Check token when there is one', () async {
      http.Request? sent;
      final api = ApiClient(
        idTokenProvider: () async => 'id-token',
        appCheckTokenProvider: () async => 'ac-token',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('{}', 200);
        }),
      );

      await api.getJson('/v1/babies');

      expect(sent!.headers['Authorization'], 'Bearer id-token');
      expect(sent!.headers['X-Firebase-AppCheck'], 'ac-token');
    });

    test('without a token the request still goes out, without the header',
        () async {
      http.Request? sent;
      final api = ApiClient(
        idTokenProvider: () async => 'id-token',
        appCheckTokenProvider: () async => null,
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('{}', 200);
        }),
      );

      await api.getJson('/v1/babies');

      expect(sent!.headers.containsKey('X-Firebase-AppCheck'), isFalse);
    });

    test('reads the ID token and the App Check token at the same time',
        () async {
      final idToken = Completer<String?>();
      var appCheckAsked = false;
      final api = ApiClient(
        idTokenProvider: () => idToken.future,
        appCheckTokenProvider: () async {
          appCheckAsked = true;
          return 'ac-token';
        },
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final request = api.getJson('/v1/babies');
      await Future<void>.delayed(Duration.zero);
      expect(appCheckAsked, isTrue, reason: 'asked before the ID token arrived');

      idToken.complete('id-token');
      await request;
    });

    test('public requests (version check) never wait for App Check', () async {
      var appCheckAsked = false;
      final api = ApiClient(
        idTokenProvider: () async => 'id-token',
        appCheckTokenProvider: () {
          appCheckAsked = true;
          return Completer<String?>().future;
        },
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'minimum_version': '1.0.0', 'store_url': 'x'}),
            200,
          ),
        ),
      );

      final json = await api.getJsonPublic('/v1/app/version?platform=android');

      expect(json['minimum_version'], '1.0.0');
      expect(appCheckAsked, isFalse);
    });

    group('membership_ended', () {
      ApiClient client(List<ApiException> handled) {
        final api = ApiClient(
          idTokenProvider: () async => 'id-token',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'detail': {'error': 'membership_ended'},
              }),
              403,
            ),
          ),
        );
        api.registerMembershipEndedHandler((e) async => handled.add(e));
        return api;
      }

      test('runs the app-wide handler for a normal request', () async {
        final handled = <ApiException>[];
        await expectLater(
          client(handled).getJson('/v1/babies/b/home-summary'),
          throwsA(isA<ApiException>()),
        );
        expect(handled, hasLength(1));
      });

      test('a prefetch (notifyMembershipEnded: false) only throws', () async {
        final handled = <ApiException>[];
        await expectLater(
          client(handled).getJson(
            '/v1/babies/b/home-summary',
            notifyMembershipEnded: false,
          ),
          throwsA(isA<ApiException>()),
        );
        expect(handled, isEmpty);
      });
    });
  });
}
