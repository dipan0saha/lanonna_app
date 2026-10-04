import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/router/deep_link_navigation.dart';

void main() {
  group('normalizeAppDeepLinkPath', () {
    test('maps /account to /profile', () {
      expect(normalizeAppDeepLinkPath('/account'), '/profile');
      expect(normalizeAppDeepLinkPath('/account/edit'), '/profile/edit');
    });

    test('maps bare /notifications to inbox', () {
      expect(normalizeAppDeepLinkPath('/notifications'), '/notifications/inbox');
    });

    test('allows nested notification paths', () {
      expect(
        normalizeAppDeepLinkPath('/notifications/inbox'),
        '/notifications/inbox',
      );
    });

    test('rejects unknown paths', () {
      expect(normalizeAppDeepLinkPath('/unknown'), isNull);
    });

    test('prefixes relative paths', () {
      expect(normalizeAppDeepLinkPath('home'), '/home');
    });

    test('allows /settings', () {
      expect(normalizeAppDeepLinkPath('/settings'), '/settings');
    });

    test('allows invite accept for FCM and inbox deep links', () {
      expect(
        normalizeAppDeepLinkPath('/invite-accept?token=abc'),
        '/invite-accept?token=abc',
      );
    });
  });
}
