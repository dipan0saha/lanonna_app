import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../l10n/app_localizations.dart';

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
    this.scrollBody = true,
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
  /// When false, [body] fills the area below the top row (e.g. carousels in [Expanded]).
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              child: scrollBody
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppMetrics.horizontalPadding,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: body,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppMetrics.horizontalPadding,
                      ),
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
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          if (showBack)
            Semantics(
              button: true,
              label: l10n.actionBack,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.scaffoldStripe,
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
