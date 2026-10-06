import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/presentation/event_form_screen.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository(this.baby) : super(ApiClient(idTokenProvider: () async => null));

  final BabySummary baby;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async => baby;
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository() : super(ApiClient(idTokenProvider: () async => null));
}

class _FakeGalleryRepository extends GalleryRepository {
  _FakeGalleryRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async =>
      [];
}

void main() {
  testWidgets('event form shows prototype labels and save button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Test Baby',
      role: 'owner',
      lifecycleStatus: 'expecting',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRepository>(create: (_) => _FakeHomeRepository(baby)),
          ChangeNotifierProvider<CalendarRepository>(create: (_) => _FakeCalendarRepository()),
          ChangeNotifierProvider<GalleryRepository>(create: (_) => _FakeGalleryRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EventFormScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Save Event').evaluate().isNotEmpty) break;
    }

    expect(find.text('New Event'), findsOneWidget);
    expect(find.text('Event Title'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Save Event'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
  });
}
