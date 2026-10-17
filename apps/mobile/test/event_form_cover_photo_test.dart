import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/media/photo_selection.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/photo_selection_preview.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/event_form_screen.dart';
import 'package:lanonna/features/calendar/presentation/widgets/event_form_widgets.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_calendar_repository.dart';
import 'support/fake_gallery_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_image_picker.dart';

final _l10n = AppLocalizationsEn();

EventDetail _existingEvent() => EventDetail(
  id: 'ev-1',
  title: 'Gender reveal',
  description: null,
  startsAt: DateTime.utc(2030, 6, 1, 16),
  endsAt: null,
  location: null,
  videoCallUrl: null,
  coverPhotoId: 'old-photo',
  coverPhotoDisplayUrl: null,
  rsvpSummary: RsvpSummary(going: 0, maybe: 0, cantGo: 0),
  viewerRsvp: null,
  rsvpAttendees: [],
  comments: [],
);

class _Harness {
  _Harness({
    required this.calendar,
    required this.gallery,
    required this.picker,
  });

  final FakeCalendarRepository calendar;
  final FakeGalleryRepository gallery;
  final FakeImagePickerPlatform picker;
  var popped = false;
}

Future<_Harness> _pumpForm(WidgetTester tester, {String? eventId}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = SelectedBabyStore(await SharedPreferences.getInstance());
  final baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    role: 'owner',
    lifecycle: BabyLifecycle.expecting,
  );
  final harness = _Harness(
    calendar: FakeCalendarRepository(detailByFetch: _existingEvent),
    gallery: FakeGalleryRepository(),
    picker: FakeImagePickerPlatform.install(),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('calendar')),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, _) => EventFormScreen(eventId: eventId),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
        Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
        Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
        ChangeNotifierProvider<CalendarRepository>.value(
          value: harness.calendar,
        ),
        ChangeNotifierProvider<GalleryRepository>.value(value: harness.gallery),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  unawaited(router.push<bool>('/form').then((_) => harness.popped = true));
  await tester.pumpAndSettle();
  return harness;
}

PhotoSelection _coverSelection(WidgetTester tester) => tester
    .widget<PrototypeEventCoverUpload>(find.byType(PrototypeEventCoverUpload))
    .selection;

Finder _coverBusySpinner() => find.descendant(
  of: find.byType(PrototypeEventCoverUpload),
  matching: find.byType(CircularProgressIndicator),
);

Future<void> _chooseCoverOption(WidgetTester tester, String option) async {
  await tester.tap(find.byType(PrototypeEventCoverUpload));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('create: a new photo previews before save and uploads on save', (
    tester,
  ) async {
    final h = await _pumpForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Baby shower');

    await _chooseCoverOption(tester, _l10n.eventCoverUploadNew);

    expect(h.picker.picks, 1);
    expect(_coverSelection(tester).localFile?.path, '/tmp/picked_cover.jpg');
    expect(
      find.descendant(
        of: find.byType(PrototypeEventCoverUpload),
        matching: find.byType(LocalPhotoImage),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    expect(
      h.gallery.uploadedFiles,
      isEmpty,
      reason: 'nothing uploads before save',
    );

    final upload = Completer<String>();
    h.gallery.uploadResults.add(upload);
    await _tapSave(tester, _l10n.calendarSaveEvent);

    expect(h.gallery.uploadedFiles.single.path, '/tmp/picked_cover.jpg');
    expect(_coverBusySpinner(), findsOneWidget);
    expect(find.text(_l10n.notificationPrefsSaving), findsOneWidget);
    expect(h.calendar.createdCoverIds, isEmpty);

    upload.complete('new-photo');
    await tester.pumpAndSettle();

    expect(h.calendar.createdCoverIds, ['new-photo']);
    expect(h.popped, isTrue);
  });

  testWidgets('edit: a new photo replaces the old cover in preview and save', (
    tester,
  ) async {
    final h = await _pumpForm(tester, eventId: 'ev-1');
    expect(_coverSelection(tester).remoteRef, 'old-photo');

    await _chooseCoverOption(tester, _l10n.eventCoverUploadNew);

    final picked = _coverSelection(tester);
    expect(picked.localFile?.path, '/tmp/picked_cover.jpg');
    expect(picked.remoteRef, isNull);
    expect(
      find.descendant(
        of: find.byType(PrototypeEventCoverUpload),
        matching: find.byType(LocalPhotoImage),
      ),
      findsOneWidget,
    );

    await _tapSave(tester, _l10n.calendarSaveChanges);
    await tester.pumpAndSettle();

    expect(h.gallery.uploadedFiles, hasLength(1));
    expect(h.calendar.updatedCoverIds, ['uploaded-1']);
    expect(h.popped, isTrue);
  });

  testWidgets('edit: "No cover photo" clears the cover on save', (
    tester,
  ) async {
    final h = await _pumpForm(tester, eventId: 'ev-1');

    await _chooseCoverOption(tester, _l10n.eventCoverNone);

    expect(_coverSelection(tester).hasPhoto, isFalse);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await _tapSave(tester, _l10n.calendarSaveChanges);
    await tester.pumpAndSettle();

    expect(h.gallery.uploadedFiles, isEmpty);
    expect(h.calendar.updatedCoverIds, [null]);
  });

  testWidgets('a cancelled device picker keeps the current cover', (
    tester,
  ) async {
    final h = await _pumpForm(tester, eventId: 'ev-1');
    h.picker.nextPath = null;

    await tester.tap(find.byType(PrototypeEventCoverUpload));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.eventCoverUploadNew));
    await tester.pumpAndSettle();
    // Sheet stays open; dismiss it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(_coverSelection(tester).remoteRef, 'old-photo');
  });

  testWidgets(
    'a failed upload shows a localized error and keeps the photo for retry',
    (tester) async {
      final h = await _pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Baby shower');
      await _chooseCoverOption(tester, _l10n.eventCoverUploadNew);

      final failing = Completer<String>();
      h.gallery.uploadResults.add(failing);
      await _tapSave(tester, _l10n.calendarSaveEvent);
      failing.completeError(const SocketException('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(_l10n.errorOffline), findsOneWidget);
      expect(_coverBusySpinner(), findsNothing);
      expect(_coverSelection(tester).needsUpload, isTrue);
      expect(h.calendar.createdCoverIds, isEmpty);
      expect(h.popped, isFalse);

      await tester.pumpAndSettle();
      await _tapSave(tester, _l10n.calendarSaveEvent);
      await tester.pumpAndSettle();

      expect(h.gallery.uploadedFiles, hasLength(2));
      expect(h.calendar.createdCoverIds, ['uploaded-2']);
    },
  );

  testWidgets('a failed event save does not upload the photo again on retry', (
    tester,
  ) async {
    final h = await _pumpForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Baby shower');
    await _chooseCoverOption(tester, _l10n.eventCoverUploadNew);
    h.calendar.nextSaveError = const SocketException('offline');

    await _tapSave(tester, _l10n.calendarSaveEvent);
    await tester.pumpAndSettle();

    expect(find.text(_l10n.errorOffline), findsOneWidget);
    expect(_coverSelection(tester).remoteRef, 'uploaded-1');
    expect(
      _coverSelection(tester).localFile,
      isNotNull,
      reason: 'preview kept',
    );

    await _tapSave(tester, _l10n.calendarSaveEvent);
    await tester.pumpAndSettle();

    expect(h.gallery.uploadedFiles, hasLength(1));
    expect(h.calendar.createdCoverIds, ['uploaded-1', 'uploaded-1']);
    expect(h.popped, isTrue);
  });
}
