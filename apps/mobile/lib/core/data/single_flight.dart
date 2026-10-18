/// Shares one in-flight request between concurrent callers.
///
/// While [run] is waiting on a task, every other [run] call gets the same
/// future instead of starting a second request. Once the task completes (or
/// fails), the next [run] starts a new one. [cancel] forgets the in-flight
/// task, so a result from before a reset is never shared with later callers.
class SingleFlight<T> {
  Future<T>? _inFlight;

  bool get isInFlight => _inFlight != null;

  Future<T> run(Future<T> Function() task) {
    final existing = _inFlight;
    if (existing != null) return existing;
    late final Future<T> future;
    future = Future<T>.sync(task).whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  void cancel() => _inFlight = null;
}

/// [SingleFlight] per key (e.g. one in-flight fetch per photo id).
class KeyedSingleFlight<K, T> {
  final Map<K, Future<T>> _inFlight = {};

  bool isInFlight(K key) => _inFlight.containsKey(key);

  Future<T> run(K key, Future<T> Function() task) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    late final Future<T> future;
    future = Future<T>.sync(task).whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  void cancelAll() => _inFlight.clear();
}
