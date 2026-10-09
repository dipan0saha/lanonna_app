import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/account/data/notifications_repository.dart';
import '../router/deep_link_navigation.dart';

class PushNotificationService {
  PushNotificationService(this._notificationsRepo);

  final NotificationsRepository _notificationsRepo;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _lastRegisteredToken;

  Future<void> start({
    required Stream<User?> authStateChanges,
    void Function(String? deepLink, String? babyProfileId)? onDeepLink,
    void Function(
      BuildContext context,
      String? deepLink,
      String? babyProfileId,
    )? onOpenDeepLink,
    BuildContext? context,
  }) async {
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    _authSub = authStateChanges.listen((user) async {
      if (user == null) {
        await _unregisterCurrentToken();
        return;
      }
      await _registerCurrentToken();
    });

    _tokenRefreshSub = messaging.onTokenRefresh.listen((token) async {
      if (FirebaseAuth.instance.currentUser == null) return;
      await _registerToken(token);
    });

    void openDeepLink(Map<String, dynamic> data) {
      final link = data['deep_link'] as String?;
      final babyProfileId = data['baby_profile_id'] as String?;
      if (onDeepLink != null) {
        onDeepLink(link, babyProfileId);
        return;
      }
      if (context != null && context.mounted) {
        if (onOpenDeepLink != null) {
          onOpenDeepLink(context, link, babyProfileId);
        } else {
          navigateAppDeepLink(
            context,
            link,
            babyProfileId: babyProfileId,
          );
        }
      }
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      openDeepLink(message.data);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openDeepLink(initial.data);
      });
    }

    if (FirebaseAuth.instance.currentUser != null) {
      await _registerCurrentToken();
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }

  Future<void> unregisterOnSignOut() => _unregisterCurrentToken();

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (_) {
      // App Check / network may block token registration on dev emulators.
    }
  }

  Future<void> _registerToken(String token) async {
    if (_lastRegisteredToken == token &&
        FirebaseAuth.instance.currentUser != null) {
      return;
    }
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await _notificationsRepo.registerDeviceToken(
        fcmToken: token,
        platform: platform,
      );
      _lastRegisteredToken = token;
    } catch (_) {
      // Non-fatal for cold start (e.g. App Check not configured on emulator).
    }
  }

  Future<void> _unregisterCurrentToken() async {
    final token = _lastRegisteredToken ?? await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _notificationsRepo.unregisterDeviceToken(token);
      } catch (_) {}
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    _lastRegisteredToken = null;
  }
}
