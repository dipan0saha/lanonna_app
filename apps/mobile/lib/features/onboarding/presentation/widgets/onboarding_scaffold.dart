import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';

/// Shared scaffold for onboarding screens — PRD padding and pinned bottom CTA.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.body,
    this.showBack = false,
    this.showSkip = false,
    this.onBack,
    this.onSkip,
    this.skipLabel = 'Skip',
    this.bottom,
    this.pinBottomCta = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final bool showBack;
  final bool showSkip;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String skipLabel;
  final Widget? bottom;
  final bool pinBottomCta;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: _TopRow(
                showBack: showBack,
                showSkip: showSkip,
                onBack: onBack,
                onSkip: onSkip,
                skipLabel: skipLabel,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.horizontalPadding,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: body,
              ),
            ),
            if (pinBottomCta && bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppMetrics.horizontalPadding,
                  0,
                  AppMetrics.horizontalPadding,
                  16,
                ),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.showBack,
    required this.showSkip,
    this.onBack,
    this.onSkip,
    required this.skipLabel,
  });

  final bool showBack;
  final bool showSkip;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          if (showBack)
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F3),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '←',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (showSkip)
            GestureDetector(
              onTap: onSkip,
              child: Text(
                skipLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
