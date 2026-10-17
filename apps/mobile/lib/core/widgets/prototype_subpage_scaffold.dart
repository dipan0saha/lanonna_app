import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/subpage_navigation.dart';
import '../theme/app_colors.dart';
import 'app_icon_button.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import '../../l10n/app_localizations.dart';

/// In-body back row + title (prototype subpages). Home top bar is for tab roots only.
class PrototypeSubpageScaffold extends StatelessWidget {
  PrototypeSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  bool _routeCanPop(BuildContext context) {
    if (onBack != null) return false;
    final router = GoRouter.maybeOf(context);
    if (router != null) return router.canPop();
    return Navigator.of(context).canPop();
  }

  void _handleBack(BuildContext context) {
    final custom = onBack;
    if (custom != null) {
      custom();
      return;
    }
    popOrGoHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _routeCanPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  4,
                  4,
                  AppMetrics.horizontalPadding,
                  8,
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      semanticsId: 'subpage_back',
                      label: l10n.actionBack,
                      onPressed: () => _handleBack(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.textStyles.titleMedium,
                      ),
                    ),
                    if (actions != null && actions!.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: actions!)
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
