import 'package:shared_preferences/shared_preferences.dart';

/// Who the signed-in user is, as shown on their avatar: display name, email
/// (the initials fallback) and avatar URL.
class AccountIdentity {
  const AccountIdentity({this.displayName, this.email, this.avatarUrl});

  final String? displayName;
  final String? email;
  final String? avatarUrl;
}

/// Last [AccountIdentity] loaded from the server, kept on disk so the shell
/// avatar shows the right initials (and cached photo) when the profile cannot
/// load, e.g. an offline cold start. Same idea as `SelectedBabyStore` keeping
/// the baby name for the shell title.
///
/// The identity belongs to the user who loaded it; another account never
/// sees it, and sign-out clears it.
class AccountIdentityStore {
  AccountIdentityStore(this._prefs);

  final SharedPreferences _prefs;
  static const _uidKey = 'account_identity_uid';
  static const _nameKey = 'account_identity_display_name';
  static const _emailKey = 'account_identity_email';
  static const _avatarKey = 'account_identity_avatar_url';

  /// The identity [uid] last loaded on this device, or `null`.
  AccountIdentity? read(String? uid) {
    if (uid == null || _prefs.getString(_uidKey) != uid) return null;
    return AccountIdentity(
      displayName: _prefs.getString(_nameKey),
      email: _prefs.getString(_emailKey),
      avatarUrl: _prefs.getString(_avatarKey),
    );
  }

  Future<void> remember(String uid, AccountIdentity identity) async {
    await _prefs.setString(_uidKey, uid);
    await _setOrRemove(_nameKey, identity.displayName);
    await _setOrRemove(_emailKey, identity.email);
    await _setOrRemove(_avatarKey, identity.avatarUrl);
  }

  Future<void> clear() async {
    await _prefs.remove(_uidKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_emailKey);
    await _prefs.remove(_avatarKey);
  }

  Future<void> _setOrRemove(String key, String? value) async {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, v);
    }
  }
}
