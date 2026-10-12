import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/widgets/prototype_subpage_scaffold.dart';
import 'package:lanonna/features/announcement/domain/announcement_navigation.dart';

void main() {
  testWidgets('save announcement leaves home under the card', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Text('home-marker'),
        ),
        GoRoute(
          path: '/baby/:id/announcement/create',
          builder: (context, state) => TextButton(
            onPressed: () => showAnnouncementCardAfterSave(
              context,
              state.pathParameters['id']!,
            ),
            child: const Text('Save Announcement'),
          ),
        ),
        GoRoute(
          path: '/baby/:id/announcement',
          builder: (_, _) => PrototypeSubpageScaffold(
            title: 'Announcement',
            body: const Text('card-marker'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/baby/baby-1/announcement/create');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Announcement'));
    await tester.pumpAndSettle();

    expect(find.text('card-marker'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('home-marker'), findsOneWidget);
  });

  testWidgets('system back from a lone card opens home', (tester) async {
    final router = GoRouter(
      initialLocation: '/baby/baby-1/announcement',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Text('home-marker'),
        ),
        GoRoute(
          path: '/baby/:id/announcement',
          builder: (_, _) => PrototypeSubpageScaffold(
            title: 'Announcement',
            body: const Text('card-marker'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('card-marker'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(find.text('card-marker'), findsNothing);
  });
}
