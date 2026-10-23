/// Elapsed time from a monotonic source (not wall clock).
abstract class MonotonicClock {
  Duration get elapsed;
}

/// [Stopwatch]-based clock; immune to device time changes.
class SystemMonotonicClock implements MonotonicClock {
  SystemMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}

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
