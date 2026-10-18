import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/router/deep_link_navigation.dart';
import 'package:lanonna/core/router/subpage_navigation.dart';

/// Same shape as `app_router.dart`: the Inbox and the activity feed are root
/// pages over the tab shell; photo and event details are under their tab's
/// path but render on the root navigator.
GoRouter _router() {
  final rootKey = GlobalKey<NavigatorState>();
  Widget page(String label, {String? link, bool leave = false}) => Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          Text(label),
          if (link != null)
            TextButton(
              onPressed: () => navigateAppDeepLink(context, link),
              child: Text('open $link'),
            ),
          if (leave)
            TextButton(
              onPressed: () => popOrGo(context, '/gallery'),
              child: const Text('leave'),
            ),
        ],
      ),
    ),
  );
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/notifications/inbox',
        parentNavigatorKey: rootKey,
        builder: (_, s) => page('INBOX', link: s.uri.queryParameters['link']),
      ),
      GoRoute(
        path: '/home/activity',
        parentNavigatorKey: rootKey,
        builder: (_, _) => page('ACTIVITY', link: '/gallery/photo/p2'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            Scaffold(body: shell, bottomNavigationBar: const Text('TABS')),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => page('HOME'))],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gallery',
                builder: (_, _) => page('GALLERY', link: '/gallery/photo/p3'),
                routes: [
                  GoRoute(
                    path: 'photo/:id',
                    parentNavigatorKey: rootKey,
                    builder: (_, s) =>
                        page('PHOTO ${s.pathParameters['id']}', leave: true),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => page('CALENDAR'),
                routes: [
                  GoRoute(
                    path: 'event/:id',
                    parentNavigatorKey: rootKey,
                    builder: (_, s) => page('EVENT ${s.pathParameters['id']}'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Finder _visible(String text) => find.text(text).hitTestable();

Future<GoRouter> _pumpAt(WidgetTester tester, String location) async {
  final router = _router();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.push(location);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Inbox -> photo -> Back returns to the Inbox', (tester) async {
    await _pumpAt(tester, '/notifications/inbox?link=/gallery/photo/p1');
    await tester.tap(find.text('open /gallery/photo/p1'));
    await tester.pumpAndSettle();
    expect(_visible('PHOTO p1'), findsOneWidget);
    await _systemBack(tester);
    expect(_visible('INBOX'), findsOneWidget);
  });

  testWidgets('Inbox -> event -> Back returns to the Inbox', (tester) async {
    await _pumpAt(tester, '/notifications/inbox?link=/calendar/event/e1');
    await tester.tap(find.text('open /calendar/event/e1'));
    await tester.pumpAndSettle();
    expect(_visible('EVENT e1'), findsOneWidget);
    await _systemBack(tester);
    expect(_visible('INBOX'), findsOneWidget);
  });

  testWidgets('Inbox -> tab target switches tab', (tester) async {
    await _pumpAt(tester, '/notifications/inbox?link=/calendar');
    await tester.tap(find.text('open /calendar'));
    await tester.pumpAndSettle();
    expect(_visible('CALENDAR'), findsOneWidget);
    expect(_visible('TABS'), findsOneWidget);
  });

  testWidgets('activity feed (root page) -> photo -> Back', (tester) async {
    await _pumpAt(tester, '/home/activity');
    await tester.tap(find.text('open /gallery/photo/p2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_visible('PHOTO p2'), findsOneWidget);
    await _systemBack(tester);
    expect(_visible('ACTIVITY'), findsOneWidget);
  });

  testWidgets('gallery tab -> photo -> Back returns to the gallery', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/gallery');
    await tester.pumpAndSettle();
    await tester.tap(find.text('open /gallery/photo/p3'));
    await tester.pumpAndSettle();
    expect(_visible('PHOTO p3'), findsOneWidget);
    await _systemBack(tester);
    expect(_visible('GALLERY'), findsOneWidget);
  });

  testWidgets('leaving a detail (delete / not found) pops to its opener', (
    tester,
  ) async {
    await _pumpAt(tester, '/notifications/inbox?link=/gallery/photo/p1');
    await tester.tap(find.text('open /gallery/photo/p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(_visible('INBOX'), findsOneWidget);
  });

  testWidgets('leaving a detail with nothing to pop opens the fallback tab', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/gallery/photo/p9');
    await tester.pumpAndSettle();
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(_visible('GALLERY'), findsOneWidget);
  });
}
