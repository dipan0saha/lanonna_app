import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/invitations/presentation/batch_invite_screen.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('from-home batch invite matches followers-invite prototype copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OnboardingRepository>(
            create: (_) => OnboardingRepository(ApiClient(idTokenProvider: () async => null)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BatchInviteScreen(mode: BatchInviteMode.fromHome),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Invite Family & Friends'), findsOneWidget);
    expect(
      find.text("We'll send each person a private link. It expires in 7 days."),
      findsOneWidget,
    );
    expect(
      find.textContaining('💡 Selecting "Mother" or "Father"'),
      findsOneWidget,
    );
    expect(find.text('Invite family & friends'), findsNothing);
  });
}
