import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/gallery/presentation/gallery_screen.dart';
import 'package:lanonna/features/gallery/presentation/widgets/gallery_view_mode_selector.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('GalleryViewModeSelector shows all sort mode labels', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GalleryViewModeSelector(
            selected: GalleryViewMode.all,
          ),
        ),
        GoRoute(
          path: '/gallery/favorites',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('favorites route')),
          ),
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

    expect(find.text('All photos'), findsOneWidget);
    expect(find.text('Recent Photos'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });
}
