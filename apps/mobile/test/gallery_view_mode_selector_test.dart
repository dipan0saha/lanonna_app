import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_chip.dart';
import 'package:lanonna/features/gallery/domain/gallery_routes.dart';
import 'package:lanonna/features/gallery/presentation/gallery_screen.dart';
import 'package:lanonna/features/gallery/presentation/widgets/gallery_view_mode_selector.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester) async {
  Widget page(GalleryViewMode mode) => Scaffold(
    body: Column(
      children: [
        GalleryViewModeSelector(selected: mode),
        Text('route ${mode.name}'),
      ],
    ),
  );
  final router = GoRouter(
    initialLocation: GalleryRoutes.gallery,
    routes: [
      GoRoute(
        path: GalleryRoutes.gallery,
        builder: (_, _) => page(GalleryViewMode.all),
        routes: [
          GoRoute(path: 'recent', builder: (_, _) => page(GalleryViewMode.recent)),
          GoRoute(
            path: 'favorites',
            builder: (_, _) => page(GalleryViewMode.favorites),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

bool _isSelected(WidgetTester tester, String label) => tester
    .widget<AppToggleChip>(find.widgetWithText(AppToggleChip, label))
    .selected;

void main() {
  testWidgets('shows the three views as shared toggle chips, All selected', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(AppToggleChip), findsNWidgets(3));
    expect(_isSelected(tester, 'All photos'), isTrue);
    expect(_isSelected(tester, 'Recent Photos'), isFalse);
    expect(_isSelected(tester, 'Favorites'), isFalse);
  });

  testWidgets('tapping a view routes to it and selects it', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('route favorites'), findsOneWidget);
    expect(_isSelected(tester, 'Favorites'), isTrue);

    await tester.tap(find.text('Recent Photos'));
    await tester.pumpAndSettle();
    expect(find.text('route recent'), findsOneWidget);

    await tester.tap(find.text('All photos'));
    await tester.pumpAndSettle();
    expect(find.text('route all'), findsOneWidget);
  });
}
