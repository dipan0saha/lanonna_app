import 'dart:async';

import '../data/single_flight.dart';

/// Reads the current App Check token from the Firebase SDK.
typedef AppCheckTokenFetch = Future<String?> Function();

/// The App Check token that `ApiClient` attaches to authorized requests.
///
/// The Firebase SDK owns the token: it keeps it in memory and on disk,
/// refreshes it before it expires, and attests again (Play Integrity /
/// App Attest) only when no valid token is stored. This class only decides
/// how the app waits for it:
///
/// * **One request at a time.** Concurrent callers share one SDK call. The
///   SDK's own de-duplication races across threads, so two requests at launch
///   could start two attestations at once.
/// * **Started early.** [prefetch] runs at launch for a signed-in user, so an
///   attestation overlaps start-up instead of starting with the first API
///   call.
/// * **Bounded wait.** A request waits at most [maxWait] for an attempt.
///   After that it is sent without the header, which is what already happens
///   when the SDK fails to produce a token. The API decides what a missing
///   token means (`APP_CHECK_ENFORCE`), so enforcement is unchanged. Once an
///   attempt has run past [maxWait], later requests stop waiting for it until
///   it finishes and the next one starts.
/// * **Failure cool-down.** After a failed read (SDK error or empty token),
///   further reads return `null` immediately until [failureCooldown] elapses,
///   so a bad attestation is not repeated on every authorized request while
///   the SDK is in backoff.
class AppCheckTokenSource {
  AppCheckTokenSource({
    required Future<void> activation,
    required AppCheckTokenFetch fetchToken,
    this.maxWait = defaultMaxWait,
    this.failureCooldown = defaultFailureCooldown,
    DateTime Function()? clock,
  }) : activated = activation,
       _fetchToken = fetchToken,
       _clock = clock ?? DateTime.now;

  /// Longer than a normal attestation (0.6 to 5 s measured on an emulator),
  /// shorter than `apiRequestTimeout` (20 s), so a hung attestation cannot hold every
  /// request until it times out.
  static const defaultMaxWait = Duration(seconds: 10);

  /// After a failed attestation, skip new SDK reads until this elapses.
  static const defaultFailureCooldown = Duration(seconds: 30);

  /// Completes once the provider is installed (`FirebaseAppCheck.activate`).
  /// Token reads wait for it.
  final Future<void> activated;
  final AppCheckTokenFetch _fetchToken;
  final DateTime Function() _clock;
  final Duration maxWait;
  final Duration failureCooldown;

  final _request = SingleFlight<String?>();
  DateTime? _requestStartedAt;
  DateTime? _failureCooldownUntil;

  bool _inFailureCooldown() {
    final until = _failureCooldownUntil;
    if (until == null) return false;
    if (!_clock().isBefore(until)) {
      _failureCooldownUntil = null;
      return false;
    }
    return true;
  }

  void _markFailure() {
    _failureCooldownUntil = _clock().add(failureCooldown);
  }

  /// The token, or `null` when the SDK has none within [maxWait].
  /// Never throws.
  Future<String?> token() {
    if (_inFailureCooldown()) return Future.value(null);
    if (!_request.isInFlight) _requestStartedAt = _clock();
    final request = _request.run(_read);
    final left = maxWait - _clock().difference(_requestStartedAt!);
    if (left <= Duration.zero) return Future.value(null);
    return request.timeout(left, onTimeout: () => null);
  }

  /// Starts reading the token without waiting for it.
  void prefetch() => unawaited(token());

  Future<String?> _read() async {
    try {
      await activated;
      final token = await _fetchToken();
      if (token == null || token.isEmpty) {
        _markFailure();
        return null;
      }
      _failureCooldownUntil = null;
      return token;
    } catch (_) {
      _markFailure();
      return null;
    }
  }
}
