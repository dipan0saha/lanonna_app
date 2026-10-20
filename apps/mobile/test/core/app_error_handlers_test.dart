import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/observability/app_error_handlers.dart';
import 'package:lanonna/core/observability/crash_reporter.dart';

void main() {
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorCallback? originalPlatformOnError;

  setUp(() {
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    resetAppErrorHandlersForTest();
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  test('chains FlutterError to the reporter and the existing handler', () {
    final previous = <FlutterErrorDetails>[];
    FlutterError.onError = previous.add;
    final reporter = NoOpCrashReporter();
    configureAppErrorReporting(reporter: reporter, enabled: true);

    final details = FlutterErrorDetails(
      exception: StateError('test'),
      library: 'test',
    );
    FlutterError.onError?.call(details);

    expect(reporter.flutterErrors, hasLength(1));
    expect(reporter.flutterErrors.first.exception, isA<StateError>());
    expect(previous, [details]);
  });

  test('does not install handlers when disabled', () {
    final reporter = NoOpCrashReporter();
    final before = FlutterError.onError;
    configureAppErrorReporting(reporter: reporter, enabled: false);
    expect(FlutterError.onError, before);
    expect(reporter.flutterErrors, isEmpty);
  });

  test('installs once even when configured twice', () {
    final previous = <FlutterErrorDetails>[];
    FlutterError.onError = previous.add;
    final reporter = NoOpCrashReporter();
    configureAppErrorReporting(reporter: reporter, enabled: true);
    configureAppErrorReporting(reporter: reporter, enabled: true);

    FlutterError.onError?.call(FlutterErrorDetails(exception: 'x'));

    expect(reporter.flutterErrors, hasLength(1));
    expect(previous, hasLength(1));
  });

  test('PlatformDispatcher.onError records fatal errors and chains', () {
    final chained = <Object>[];
    PlatformDispatcher.instance.onError = (error, stack) {
      chained.add(error);
      return false;
    };
    final reporter = NoOpCrashReporter();
    configureAppErrorReporting(reporter: reporter, enabled: true);

    final error = Exception('platform');
    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.current,
    );

    expect(handled, isFalse);
    expect(chained, [error]);
    expect(reporter.errors, hasLength(1));
    expect(reporter.errors.first.$3, isTrue);
  });

  test('reset restores the original handlers', () {
    final previous = <FlutterErrorDetails>[];
    FlutterError.onError = previous.add;
    final installedBefore = FlutterError.onError;
    configureAppErrorReporting(reporter: NoOpCrashReporter(), enabled: true);
    expect(FlutterError.onError, isNot(same(installedBefore)));

    resetAppErrorHandlersForTest();

    expect(FlutterError.onError, same(installedBefore));
  });
}
