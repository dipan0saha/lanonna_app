import 'package:flutter/foundation.dart';

/// Home tab only (nav re-tap, cross-tab home teasers; or the tab was shown).
class HomeTabRefreshListenable extends ChangeNotifier {
  void notifyRefresh() => notifyListeners();
}

/// Baby switch, membership refresh, deep links — all shell tabs.
class BabyContextRefreshListenable extends ChangeNotifier {
  void notifyRefresh() => notifyListeners();
}

/// Coordinates tab reloads: home-only refresh vs baby-context change.
class HomeRefreshSignal {
  final homeTab = HomeTabRefreshListenable();
  final homeTabShown = HomeTabRefreshListenable();
  final babyContext = BabyContextRefreshListenable();

  /// Home data changed (or the user re-tapped Home): refetch now.
  void notifyHomeShouldRefresh() {
    homeTab.notifyRefresh();
  }

  /// The user switched to the Home tab: refetch only data that is no longer
  /// current (`HomeRepository.summaryFreshFor`).
  void notifyHomeTabShown() {
    homeTabShown.notifyRefresh();
  }

  void notifyBabyContextChanged() {
    babyContext.notifyRefresh();
  }
}
