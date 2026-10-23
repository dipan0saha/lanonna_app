import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/time/monotonic_clock.dart';

void main() {
  test('system clock reads the kernel clock and moves forward', () async {
    final clock = SystemMonotonicClock();
    final first = clock.elapsed;
    // The kernel boot-time clock is far past zero; a fresh Stopwatch is not.
    expect(first, greaterThan(const Duration(seconds: 1)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final second = clock.elapsed;
    expect(
      second - first,
      greaterThanOrEqualTo(const Duration(milliseconds: 45)),
    );
    expect(second - first, lessThan(const Duration(seconds: 5)));
  });
}
