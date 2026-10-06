import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/baby/domain/create_baby_mode.dart';
import 'package:lanonna/features/baby/presentation/create_baby_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('in-app create baby uses Add Baby shell and shared form fields', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    final api = ApiClient(idTokenProvider: () async => null);
    final repository = OnboardingRepository(api);
    final coordinator = OnboardingCoordinator(storage: storage, repository: repository);
    await coordinator.hydrate();
    final babyStore = SelectedBabyStore(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
          Provider<OnboardingRepository>.value(value: repository),
          Provider<ApiClient>.value(value: api),
          Provider<HomeRepository>(create: (_) => HomeRepository(api)),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: babyStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateBabyScreen(mode: CreateBabyMode.inApp),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add Baby'), findsOneWidget);
    expect(find.text("Create your baby's profile"), findsNothing);
    expect(find.text('Expected Due Date'), findsOneWidget);
    expect(find.text('Profile photo (optional)'), findsOneWidget);
    expect(find.text('Create Baby'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Also share this photo in the gallery'), findsNothing);
  });
}
