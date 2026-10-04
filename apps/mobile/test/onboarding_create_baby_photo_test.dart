import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/onboarding/data/create_baby_draft.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_create_baby_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({
  OnboardingCoordinator coordinator,
  OnboardingStorage storage,
  OnboardingRepository repository,
  SelectedBabyStore babyStore,
  ApiClient api,
})> _fixtures() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  await storage.saveOnboardingPath(OnboardingPath.owner);
  final api = ApiClient(idTokenProvider: () async => null);
  final repository = OnboardingRepository(api);
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: repository,
  );
  await coordinator.hydrate();
  final babyStore = SelectedBabyStore(prefs);
  return (
    coordinator: coordinator,
    storage: storage,
    repository: repository,
    babyStore: babyStore,
    api: api,
  );
}

Widget _wrap(
  Widget child, {
  required OnboardingCoordinator coordinator,
  required OnboardingStorage storage,
  required OnboardingRepository repository,
  required SelectedBabyStore babyStore,
  required ApiClient api,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      Provider<OnboardingRepository>.value(value: repository),
      Provider<ApiClient>.value(value: api),
      Provider<HomeRepository>.value(value: HomeRepository(api)),
      ChangeNotifierProvider<SelectedBabyStore>.value(value: babyStore),
      ChangeNotifierProvider<AppSession>(
        create: (_) => AppSession(
          repository: repository,
          storage: storage,
          coordinator: coordinator,
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

void main() {
  test('CreateBabyDraft round-trips sharePhotoToGallery', () {
    const draft = CreateBabyDraft(
      photoPath: '/tmp/test.jpg',
      sharePhotoToGallery: true,
    );
    final restored = CreateBabyDraft.fromJson(draft.toJson());
    expect(restored.sharePhotoToGallery, isTrue);
    expect(restored.photoPath, '/tmp/test.jpg');

    const defaultDraft = CreateBabyDraft(photoPath: '/tmp/a.jpg');
    expect(
      CreateBabyDraft.fromJson(defaultDraft.toJson()).sharePhotoToGallery,
      isFalse,
    );
  });

  testWidgets('gallery opt-in hidden without profile photo', (tester) async {
    final fx = await _fixtures();
    await tester.pumpWidget(
      _wrap(
        const OnboardingCreateBabyScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
        babyStore: fx.babyStore,
        api: fx.api,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Also share this photo in the gallery'), findsNothing);
    expect(find.text('Profile photo (optional)'), findsOneWidget);
  });

  testWidgets('gallery opt-in shown when draft has photo', (tester) async {
    final fx = await _fixtures();
    await fx.coordinator.saveCreateBabyDraft(
      const CreateBabyDraft(
        photoPath: '/tmp/onboarding_baby_photo_test.jpg',
        sharePhotoToGallery: true,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const OnboardingCreateBabyScreen(),
        coordinator: fx.coordinator,
        storage: fx.storage,
        repository: fx.repository,
        babyStore: fx.babyStore,
        api: fx.api,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Also share this photo in the gallery'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkbox.value, isTrue);
  });
}
