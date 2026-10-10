import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
import '../data/home_refresh_signal.dart';
import '../data/selected_baby_store.dart';

/// Reload baby-scoped shell tabs when selection changes, [HomeRefreshSignal] fires,
/// or connectivity returns after being offline.
mixin BabyContextReload<T extends StatefulWidget> on State<T> {
  SelectedBabyStore? _babyContextStore;
  HomeRefreshSignal? _babyContextRefresh;
  ConnectivityService? _babyContextConnectivity;
  var _babyContextWasOffline = false;

  void onBabyContextReload();

  void registerBabyContextListeners() {
    final store = context.read<SelectedBabyStore>();
    if (_babyContextStore != store) {
      _babyContextStore?.removeListener(_handleBabyContextReload);
      _babyContextStore = store;
      _babyContextStore!.addListener(_handleBabyContextReload);
    }
    final refresh = context.read<HomeRefreshSignal>();
    if (_babyContextRefresh != refresh) {
      _babyContextRefresh?.removeListener(_handleBabyContextReload);
      _babyContextRefresh = refresh;
      _babyContextRefresh!.addListener(_handleBabyContextReload);
    }
    final connectivity = context.read<ConnectivityService>();
    if (_babyContextConnectivity != connectivity) {
      _babyContextConnectivity?.removeListener(_handleConnectivityChanged);
      _babyContextConnectivity = connectivity;
      _babyContextWasOffline = !connectivity.isOnline;
      _babyContextConnectivity!.addListener(_handleConnectivityChanged);
    }
  }

  void disposeBabyContextListeners() {
    _babyContextStore?.removeListener(_handleBabyContextReload);
    _babyContextRefresh?.removeListener(_handleBabyContextReload);
    _babyContextConnectivity?.removeListener(_handleConnectivityChanged);
    _babyContextStore = null;
    _babyContextRefresh = null;
    _babyContextConnectivity = null;
  }

  void _handleBabyContextReload() {
    if (mounted) onBabyContextReload();
  }

  void _handleConnectivityChanged() {
    if (!mounted) return;
    final online = _babyContextConnectivity?.isOnline ?? true;
    if (online && _babyContextWasOffline) {
      _babyContextWasOffline = false;
      onBabyContextReload();
    } else if (!online) {
      _babyContextWasOffline = true;
    }
  }
}
