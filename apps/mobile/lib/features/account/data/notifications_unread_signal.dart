import 'package:flutter/foundation.dart';

/// Shell bell dot and other listeners refresh when inbox unread state changes.
class NotificationsUnreadSignal extends ChangeNotifier {
  void notifyUnreadChanged() => notifyListeners();
}
