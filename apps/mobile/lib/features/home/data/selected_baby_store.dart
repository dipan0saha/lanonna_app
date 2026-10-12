import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedBabyStore extends ChangeNotifier {
  SelectedBabyStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'selected_baby_id';
  var _selectionGeneration = 0;

  String? get selectedBabyId => _prefs.getString(_key);

  /// Increments whenever the stored id changes. In-flight baby resolution
  /// must not write an older selection back over a newer one.
  int get selectionGeneration => _selectionGeneration;

  Future<void> setSelectedBabyId(String id) async {
    final changed = selectedBabyId != id;
    await _prefs.setString(_key, id);
    if (changed) _selectionGeneration += 1;
    notifyListeners();
  }

  Future<void> clearSelectedBabyId() async {
    if (selectedBabyId != null) _selectionGeneration += 1;
    await _prefs.remove(_key);
    notifyListeners();
  }
}
