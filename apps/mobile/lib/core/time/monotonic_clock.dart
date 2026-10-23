import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Elapsed time from a monotonic source that keeps counting while the device
/// sleeps (Android `SystemClock.elapsedRealtime()` semantics), so it is safe
/// for "how long was the app away" decisions. Never the wall clock, which the
/// user can change.
abstract class MonotonicClock {
  Duration get elapsed;
}

/// Reads the kernel clock directly:
/// - Android/Linux: `CLOCK_BOOTTIME` (what `elapsedRealtime()` uses).
/// - iOS/macOS: `CLOCK_MONOTONIC`, which on Darwin includes sleep.
///
/// Not [Stopwatch]: on Android it reads `CLOCK_MONOTONIC`, which stops while
/// the device is suspended (screen off / doze), so time away would be
/// undercounted and the app could skip a lock it owes.
///
/// Other platforms (or an unexpected clock failure) fall back to a
/// [Stopwatch], the best clock available there.
class SystemMonotonicClock implements MonotonicClock {
  SystemMonotonicClock() : _read = _kernelClockReader() ?? _stopwatchReader();

  final Duration Function() _read;

  @override
  Duration get elapsed => _read();
}

const _clockBoottimeLinux = 7;
const _clockMonotonicDarwin = 6;

final class _Timespec extends Struct {
  @Long()
  external int tvSec;

  @Long()
  external int tvNsec;
}

typedef _ClockGettimeNative = Int Function(Int clockId, Pointer<_Timespec> tp);
typedef _ClockGettime = int Function(int clockId, Pointer<_Timespec> tp);

Duration Function()? _kernelClockReader() {
  final int clockId;
  if (Platform.isAndroid || Platform.isLinux) {
    clockId = _clockBoottimeLinux;
  } else if (Platform.isIOS || Platform.isMacOS) {
    clockId = _clockMonotonicDarwin;
  } else {
    return null;
  }
  final _ClockGettime clockGettime;
  try {
    clockGettime = DynamicLibrary.process()
        .lookupFunction<_ClockGettimeNative, _ClockGettime>('clock_gettime');
  } on ArgumentError {
    return null;
  }
  Duration? read() => using((arena) {
    final ts = arena<_Timespec>();
    if (clockGettime(clockId, ts) != 0) return null;
    return Duration(
      microseconds:
          ts.ref.tvSec * Duration.microsecondsPerSecond + ts.ref.tvNsec ~/ 1000,
    );
  });
  if (read() == null) return null;
  return () => read()!;
}

Duration Function() _stopwatchReader() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}
