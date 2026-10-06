import 'package:flutter/material.dart';

import '../../../baby/domain/create_baby_mode.dart';
import '../../../baby/presentation/create_baby_screen.dart';

/// Onboarding route wrapper — same form as in-app add baby.
class OnboardingCreateBabyScreen extends StatelessWidget {
  const OnboardingCreateBabyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateBabyScreen(mode: CreateBabyMode.onboarding);
  }
}
