import 'package:lanonna/core/time/monotonic_clock.dart';

/// Test double with manual time advancement.
class FakeMonotonicClock implements MonotonicClock {
  FakeMonotonicClock([Duration initial = Duration.zero]) : _elapsed = initial;

  Duration _elapsed;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) {
    _elapsed += by;
  }
}
