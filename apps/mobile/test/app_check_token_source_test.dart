import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/app_check/app_check_token_source.dart';

void main() {
  group('AppCheckTokenSource', () {
    test('concurrent reads share one SDK call', () async {
      var calls = 0;
      final sdk = Completer<String?>();
      final source = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () {
          calls += 1;
          return sdk.future;
        },
      );

      final reads = [source.token(), source.token(), source.token()];
      await Future<void>.delayed(Duration.zero);
      sdk.complete('tok');

      expect(await Future.wait(reads), ['tok', 'tok', 'tok']);
      expect(calls, 1);
    });

    test('keeps no copy: a later read asks the SDK again (SDK owns caching)',
        () async {
      var calls = 0;
      final source = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () async {
          calls += 1;
          return 'tok-$calls';
        },
      );

      expect(await source.token(), 'tok-1');
      expect(await source.token(), 'tok-2');
      expect(calls, 2);
    });

    test('waits for activation before reading the token', () async {
      final activation = Completer<void>();
      var calls = 0;
      final source = AppCheckTokenSource(
        activation: activation.future,
        fetchToken: () async {
          calls += 1;
          return 'tok';
        },
      );

      final read = source.token();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);

      activation.complete();
      expect(await read, 'tok');
      expect(calls, 1);
    });

    test('SDK failure or empty token reads as null and never throws', () async {
      final failing = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () async => throw Exception('attestation failed'),
      );
      final empty = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () async => '',
      );

      expect(await failing.token(), isNull);
      expect(await empty.token(), isNull);
    });

    test('a hung attestation is waited for at most maxWait, then not again',
        () async {
      var calls = 0;
      final sdk = Completer<String?>();
      final source = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () {
          calls += 1;
          return sdk.future;
        },
        maxWait: const Duration(milliseconds: 40),
      );

      final watch = Stopwatch()..start();
      expect(await source.token(), isNull);
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(35));

      // Still hung: later requests go out at once instead of waiting again.
      watch.reset();
      expect(await source.token(), isNull);
      expect(watch.elapsedMilliseconds, lessThan(30));
      expect(calls, 1);
      sdk.complete(null);
    });

    test('after a hung attempt finishes, the next read asks the SDK again',
        () async {
      var calls = 0;
      final first = Completer<String?>();
      final source = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () {
          calls += 1;
          return calls == 1 ? first.future : Future.value('fresh');
        },
        maxWait: const Duration(milliseconds: 20),
      );

      expect(await source.token(), isNull);
      first.complete(null);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(await source.token(), 'fresh');
      expect(calls, 2);
    });

    test('prefetch starts the read; the first request joins it', () async {
      var calls = 0;
      final sdk = Completer<String?>();
      final source = AppCheckTokenSource(
        activation: Future.value(),
        fetchToken: () {
          calls += 1;
          return sdk.future;
        },
      );

      source.prefetch();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      final read = source.token();
      sdk.complete('tok');
      expect(await read, 'tok');
      expect(calls, 1);
    });
  });
}
