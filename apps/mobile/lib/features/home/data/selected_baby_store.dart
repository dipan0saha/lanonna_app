import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedBabyStore extends ChangeNotifier {
  SelectedBabyStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'selected_baby_id';

  String? get selectedBabyId => _prefs.getString(_key);

  Future<void> setSelectedBabyId(String id) async {
    await _prefs.setString(_key, id);
    notifyListeners();
  }
}
