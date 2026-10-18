import 'dart:async';

/// Runs independent requests together instead of one after another.
///
/// Unlike awaiting a record's `.wait` directly, a failure is rethrown as the
/// original error (for example an `ApiException`), not a
/// [ParallelWaitError], so callers keep their usual error handling, and no
/// other failure is left unhandled.
Future<(A, B)> waitBoth<A, B>(Future<A> a, Future<B> b) async {
  try {
    return await (a, b).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (e) {
    _rethrowFirst([e.errors.$1, e.errors.$2]);
  }
}

/// Three-request form of [waitBoth].
Future<(A, B, C)> waitAll3<A, B, C>(Future<A> a, Future<B> b, Future<C> c) async {
  try {
    return await (a, b, c).wait;
  } on ParallelWaitError<(A?, B?, C?), (AsyncError?, AsyncError?, AsyncError?)> catch (e) {
    _rethrowFirst([e.errors.$1, e.errors.$2, e.errors.$3]);
  }
}

Never _rethrowFirst(List<AsyncError?> errors) {
  final first = errors.firstWhere((e) => e != null)!;
  Error.throwWithStackTrace(first.error, first.stackTrace);
}
