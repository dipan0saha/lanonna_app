import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/router/app_router.dart';
import 'package:lanonna/core/router/deep_link_navigation.dart';
import 'package:lanonna/features/shell/shell_branch_index.dart';

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
      expect(
        normalizeAppDeepLinkPath('/notifications'),
        '/notifications/inbox',
      );
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

  group('tabBranchForLocation (app route tree)', () {
    final configuration = GoRouter(
      navigatorKey: appRootNavigatorKey,
      initialLocation: '/home',
      routes: buildAppRoutes(),
    ).configuration;
    int? branch(String path) => tabBranchForLocation(configuration, path);

    test('tab pages map to their shell branch', () {
      expect(branch('/home'), ShellBranchIndex.home);
      expect(branch('/gallery'), ShellBranchIndex.gallery);
      expect(branch('/gallery/recent'), ShellBranchIndex.gallery);
      expect(branch('/calendar'), ShellBranchIndex.calendar);
      expect(branch('/calendar/event/create'), ShellBranchIndex.calendar);
      expect(branch('/registry'), ShellBranchIndex.registry);
      expect(branch('/registry/item/create'), ShellBranchIndex.registry);
      expect(branch('/gamification'), ShellBranchIndex.fun);
    });

    test('drill-down details render on the root navigator', () {
      expect(branch('/gallery/photo/p1'), isNull);
      expect(branch('/gallery/photo/p1?sort=newest'), isNull);
      expect(branch('/calendar/event/e1'), isNull);
      expect(branch('/calendar/event/e1/edit'), isNull);
    });

    test('root stack pages are not tab pages', () {
      expect(branch('/notifications/inbox'), isNull);
      expect(branch('/home/activity'), isNull);
      expect(branch('/profile'), isNull);
      expect(branch('/settings'), isNull);
      expect(branch('/baby/b1/announcement'), isNull);
      expect(branch('/baby/b1/followers'), isNull);
    });

    test('unknown locations are not tab pages', () {
      expect(branch('/nope'), isNull);
    });
  });
}
