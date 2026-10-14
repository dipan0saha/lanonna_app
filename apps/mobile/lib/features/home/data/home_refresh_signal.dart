import 'package:flutter/foundation.dart';

/// Home tab only (nav re-tap, cross-tab home teasers).
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
  final babyContext = BabyContextRefreshListenable();

  void notifyHomeShouldRefresh() {
    homeTab.notifyRefresh();
  }

  void notifyBabyContextChanged() {
    babyContext.notifyRefresh();
  }
}
