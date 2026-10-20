import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/observability/app_error_handlers.dart';
import 'package:lanonna/core/observability/crash_reporter.dart';

void main() {
  tearDown(resetAppErrorHandlersForTest);

  test('forwards FlutterError to reporter when enabled', () {
    final reporter = NoOpCrashReporter();
    configureAppErrorReporting(reporter: reporter, enabled: true);

    final details = FlutterErrorDetails(
      exception: StateError('test'),
      library: 'test',
    );
    FlutterError.onError?.call(details);

    expect(reporter.flutterErrors, hasLength(1));
    expect(reporter.flutterErrors.first.exception, isA<StateError>());
  });

  test('does not install handlers when disabled', () {
    final reporter = NoOpCrashReporter();
    final before = FlutterError.onError;
    configureAppErrorReporting(reporter: reporter, enabled: false);
    expect(FlutterError.onError, before);
    expect(reporter.flutterErrors, isEmpty);
  });

  test('PlatformDispatcher.onError records fatal errors', () {
    final reporter = NoOpCrashReporter();
    configureAppErrorReporting(reporter: reporter, enabled: true);

    final handled = PlatformDispatcher.instance.onError!(
      Exception('platform'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(reporter.errors, hasLength(1));
    expect(reporter.errors.first.$3, isTrue);
  });
}
