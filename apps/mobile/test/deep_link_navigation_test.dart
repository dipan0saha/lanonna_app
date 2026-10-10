import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/router/deep_link_navigation.dart';

void main() {
  group('normalizeAppDeepLinkPath', () {
    test('maps /account hub to /profile', () {
      expect(normalizeAppDeepLinkPath('/account'), '/profile');
    });

    test('maps /profile/edit to /account/edit', () {
      expect(normalizeAppDeepLinkPath('/profile/edit'), '/account/edit');
    });

    test('keeps /account subpaths for registered routes', () {
      expect(normalizeAppDeepLinkPath('/account/edit'), '/account/edit');
      expect(normalizeAppDeepLinkPath('/account/export'), '/account/export');
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

  group('isShellDeepLinkPath', () {
    test('treats tab routes and nested shell paths as shell', () {
      expect(isShellDeepLinkPath('/home'), isTrue);
      expect(isShellDeepLinkPath('/gallery'), isTrue);
      expect(isShellDeepLinkPath('/gallery/photo/abc'), isTrue);
      expect(isShellDeepLinkPath('/calendar/event/e1'), isTrue);
      expect(isShellDeepLinkPath('/registry'), isTrue);
      expect(isShellDeepLinkPath('/gamification'), isTrue);
    });

    test('treats root stack routes as non-shell', () {
      expect(isShellDeepLinkPath('/notifications/inbox'), isFalse);
      expect(isShellDeepLinkPath('/profile'), isFalse);
      expect(isShellDeepLinkPath('/settings'), isFalse);
    });
  });

  group('shellBranchIndexForDeepLinkPath', () {
    test('maps paths to shell branch indices', () {
      expect(shellBranchIndexForDeepLinkPath('/home'), 0);
      expect(shellBranchIndexForDeepLinkPath('/gallery/recent'), 1);
      expect(shellBranchIndexForDeepLinkPath('/calendar/event/x'), 2);
      expect(shellBranchIndexForDeepLinkPath('/registry/item/create'), 3);
      expect(shellBranchIndexForDeepLinkPath('/gamification'), 4);
      expect(shellBranchIndexForDeepLinkPath('/notifications/inbox'), isNull);
    });
  });
}
