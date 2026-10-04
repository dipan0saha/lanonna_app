import 'package:flutter/foundation.dart';

/// Notifies listeners (e.g. [HomeScreen], shell tabs) to reload baby-scoped data.
class HomeRefreshSignal extends ChangeNotifier {
  void notifyHomeShouldRefresh() {
    notifyListeners();
  }

  /// Baby switcher or explicit context change — same listeners as home refresh.
  void notifyBabyContextChanged() {
    notifyListeners();
  }
}
