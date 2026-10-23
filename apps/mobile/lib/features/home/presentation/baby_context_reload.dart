import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/baby_summary.dart';
import '../../../core/network/connectivity_service.dart';
import '../data/home_refresh_signal.dart';
import '../data/selected_baby_store.dart';

/// Whether to show the full-tab loading spinner before a background revalidate.
bool tabLoadShouldShowSpinner({
  required bool hasDisplayedPayload,
  required String? loadedBabyId,
  required String? selectedBabyId,
  required int loadedSelectionGeneration,
  required int selectionGeneration,
}) {
  if (!hasDisplayedPayload) return true;
  if (loadedBabyId == null) return true;
  if (selectedBabyId != null && loadedBabyId != selectedBabyId) return true;
  if (loadedSelectionGeneration != selectionGeneration) return true;
  return false;
}

/// Whether on-screen baby tab data belongs to the current [SelectedBabyStore] selection.
///
/// Stale payload from a previous baby (e.g. offline switch before load completes)
/// must not count as displayable content for snackbar-only load failures.
bool tabDisplayedPayloadIsCurrent({
  required SelectedBabyStore store,
  required String? displayedBabyId,
  required String? loadedBabyId,
  required int loadedSelectionGeneration,
}) {
  final selectedId = store.selectedBabyId;
  if (selectedId == null || displayedBabyId == null) return false;
  if (displayedBabyId != selectedId) return false;
  if (loadedBabyId != selectedId) return false;
  if (loadedSelectionGeneration != store.selectionGeneration) return false;
  return true;
}

/// Reload baby-scoped shell tabs when [HomeRefreshSignal.babyContext] fires
/// or connectivity returns after being offline.
mixin BabyContextReload<T extends StatefulWidget> on State<T> {
  HomeRefreshSignal? _babyContextRefresh;
  ConnectivityService? _babyContextConnectivity;
  var _babyContextWasOffline = false;

  void onBabyContextReload();

  void registerBabyContextListeners() {
    final refresh = context.read<HomeRefreshSignal>();
    if (_babyContextRefresh != refresh) {
      _babyContextRefresh?.babyContext.removeListener(_handleBabyContextReload);
      _babyContextRefresh = refresh;
      _babyContextRefresh!.babyContext.addListener(_handleBabyContextReload);
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
    _babyContextRefresh?.babyContext.removeListener(_handleBabyContextReload);
    _babyContextConnectivity?.removeListener(_handleConnectivityChanged);
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

/// Home tab also reloads on [HomeRefreshSignal.homeTab] (nav re-tap, cross-tab
/// teasers) and revalidates on [HomeRefreshSignal.homeTabShown] (tab switch).
mixin HomeTabReload<T extends StatefulWidget> on State<T> {
  HomeRefreshSignal? _homeTabRefresh;

  void onHomeTabRefresh();

  void onHomeTabShown();

  void registerHomeTabRefreshListener() {
    final refresh = context.read<HomeRefreshSignal>();
    if (_homeTabRefresh != refresh) {
      _homeTabRefresh?.homeTab.removeListener(_handleHomeTabRefresh);
      _homeTabRefresh?.homeTabShown.removeListener(_handleHomeTabShown);
      _homeTabRefresh = refresh;
      _homeTabRefresh!.homeTab.addListener(_handleHomeTabRefresh);
      _homeTabRefresh!.homeTabShown.addListener(_handleHomeTabShown);
    }
  }

  void disposeHomeTabRefreshListener() {
    _homeTabRefresh?.homeTab.removeListener(_handleHomeTabRefresh);
    _homeTabRefresh?.homeTabShown.removeListener(_handleHomeTabShown);
    _homeTabRefresh = null;
  }

  void _handleHomeTabRefresh() {
    if (mounted) onHomeTabRefresh();
  }

  void _handleHomeTabShown() {
    if (mounted) onHomeTabShown();
  }
}

/// Tracks baby + selection generation for stale-while-revalidate tab loads.
mixin TabLoadGenerationCache<T extends StatefulWidget> on State<T> {
  String? cachedLoadedBabyId;
  int cachedSelectionGeneration = -1;

  void rememberTabLoadGeneration(SelectedBabyStore store, BabySummary? baby) {
    cachedLoadedBabyId = baby?.id;
    cachedSelectionGeneration = store.selectionGeneration;
  }

  bool shouldShowTabLoadSpinner(SelectedBabyStore store, {required bool hasDisplayedPayload}) {
    return tabLoadShouldShowSpinner(
      hasDisplayedPayload: hasDisplayedPayload,
      loadedBabyId: cachedLoadedBabyId,
      selectedBabyId: store.selectedBabyId,
      loadedSelectionGeneration: cachedSelectionGeneration,
      selectionGeneration: store.selectionGeneration,
    );
  }

  bool hasCurrentTabPayload(SelectedBabyStore store, String? displayedBabyId) {
    return tabDisplayedPayloadIsCurrent(
      store: store,
      displayedBabyId: displayedBabyId,
      loadedBabyId: cachedLoadedBabyId,
      loadedSelectionGeneration: cachedSelectionGeneration,
    );
  }
}
