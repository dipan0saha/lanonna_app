import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/home_refresh_signal.dart';
import '../data/selected_baby_store.dart';

/// Reload baby-scoped shell tabs when selection changes or [HomeRefreshSignal] fires.
mixin BabyContextReload<T extends StatefulWidget> on State<T> {
  SelectedBabyStore? _babyContextStore;
  HomeRefreshSignal? _babyContextRefresh;

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
  }

  void disposeBabyContextListeners() {
    _babyContextStore?.removeListener(_handleBabyContextReload);
    _babyContextRefresh?.removeListener(_handleBabyContextReload);
    _babyContextStore = null;
    _babyContextRefresh = null;
  }

  void _handleBabyContextReload() {
    if (mounted) onBabyContextReload();
  }
}
