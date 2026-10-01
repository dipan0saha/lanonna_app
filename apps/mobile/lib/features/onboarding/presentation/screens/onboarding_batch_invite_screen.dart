import 'package:flutter/material.dart';

import '../../../invitations/presentation/batch_invite_screen.dart';

class OnboardingBatchInviteScreen extends StatelessWidget {
  const OnboardingBatchInviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BatchInviteScreen(mode: BatchInviteMode.onboarding);
  }
}
