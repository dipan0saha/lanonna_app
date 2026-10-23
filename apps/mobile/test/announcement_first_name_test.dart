import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/announcement_create_screen.dart';
import 'package:provider/provider.dart';

class _EmptyAnnouncementRepository extends AnnouncementRepository {
  _EmptyAnnouncementRepository()
    : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<AnnouncementDetail?> fetch(String babyId) async => null;
}

void main() {
  testWidgets('empty first name shows the shared validation message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<AnnouncementRepository>.value(
        value: _EmptyAnnouncementRepository(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const AnnouncementCreateScreen(babyId: 'baby-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Save Announcement'));
    await tester.pump();

    expect(find.text('First name is required'), findsOneWidget);
  });
}
