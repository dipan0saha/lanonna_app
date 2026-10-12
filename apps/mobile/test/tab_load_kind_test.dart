import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/presentation/tab_load_kind.dart';

void main() {
  test('loading with nothing cached is a spinner, not an empty baby', () {
    expect(
      resolveTabLoadKind(loading: true, hasError: false, hasPayload: false),
      TabLoadKind.loading,
    );
  });

  test('a failed first load is an error', () {
    expect(
      resolveTabLoadKind(loading: false, hasError: true, hasPayload: false),
      TabLoadKind.error,
    );
  });

  test('cached payload stays visible through a failed refresh', () {
    expect(
      resolveTabLoadKind(loading: true, hasError: true, hasPayload: true),
      TabLoadKind.content,
    );
    expect(
      resolveTabLoadKind(loading: false, hasError: true, hasPayload: true),
      TabLoadKind.content,
    );
  });

  test('empty is only a successful load with no baby', () {
    expect(
      resolveTabLoadKind(loading: false, hasError: false, hasPayload: false),
      TabLoadKind.empty,
    );
  });
}
