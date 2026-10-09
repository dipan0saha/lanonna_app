import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/presentation/detail_screen_load.dart';

void main() {
  test('full-screen loader only before first content', () {
    expect(
      shouldShowDetailFullScreenLoader(
        hasContent: false,
        initialLoadInFlight: true,
      ),
      isTrue,
    );
    expect(
      shouldShowDetailFullScreenLoader(
        hasContent: true,
        initialLoadInFlight: true,
      ),
      isFalse,
    );
    expect(
      shouldShowDetailFullScreenLoader(
        hasContent: true,
        initialLoadInFlight: false,
      ),
      isFalse,
    );
  });
}
