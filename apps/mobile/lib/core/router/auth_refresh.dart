import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when Firebase auth state changes.
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}
