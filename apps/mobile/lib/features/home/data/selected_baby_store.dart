import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedBabyStore extends ChangeNotifier {
  SelectedBabyStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'selected_baby_id';
  static const _nameKey = 'selected_baby_name';
  var _selectionGeneration = 0;

  String? get selectedBabyId => _prefs.getString(_key);

  /// Last baby name resolved from the server, so the shell title survives
  /// an offline cold start when the baby list cannot be fetched.
  String? get selectedBabyName => _prefs.getString(_nameKey);

  /// Increments whenever the stored id changes. In-flight baby resolution
  /// must not write an older selection back over a newer one.
  int get selectionGeneration => _selectionGeneration;

  Future<void> setSelectedBabyId(String id) async {
    final changed = selectedBabyId != id;
    await _prefs.setString(_key, id);
    if (changed) {
      await _prefs.remove(_nameKey);
      _selectionGeneration += 1;
    }
    notifyListeners();
  }

  /// Persists the id and display name of a baby the server just returned.
  Future<void> rememberResolvedBaby(String id, String name) async {
    final idChanged = selectedBabyId != id;
    final nameChanged = selectedBabyName != name;
    if (!idChanged && !nameChanged) return;
    await _prefs.setString(_key, id);
    if (name.isEmpty) {
      await _prefs.remove(_nameKey);
    } else {
      await _prefs.setString(_nameKey, name);
    }
    if (idChanged) _selectionGeneration += 1;
    notifyListeners();
  }

  Future<void> clearSelectedBabyId() async {
    if (selectedBabyId != null) _selectionGeneration += 1;
    await _prefs.remove(_key);
    await _prefs.remove(_nameKey);
    notifyListeners();
  }
}
