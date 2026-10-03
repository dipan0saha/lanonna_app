import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Maps platform connectivity results to an online/offline flag.
bool internetStatusFromResults(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  return results.any((r) => r != ConnectivityResult.none);
}

class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  ConnectivityService._forTesting({required bool isOnline})
      : _connectivity = Connectivity(),
        _isOnline = isOnline;

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  @visibleForTesting
  static ConnectivityService forTesting({bool isOnline = true}) {
    return ConnectivityService._forTesting(isOnline: isOnline);
  }

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    _applyResults(initial);
    _subscription = _connectivity.onConnectivityChanged.listen(_applyResults);
  }

  void _applyResults(List<ConnectivityResult> results) {
    final online = internetStatusFromResults(results);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
