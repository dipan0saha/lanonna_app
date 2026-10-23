import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_cancel_text_button.dart';
import 'app_sheet_handle.dart';
import '../../l10n/app_localizations.dart';

/// Presents any sheet body with the app's shared bottom-sheet chrome
/// (surface colour, top radius). Prefer [showAppModalSheet] unless the body
/// builds its own [AppModalSheet] (e.g. a stateful body).
Future<T?> presentAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppMetrics.surfaceRadius),
      ),
    ),
    builder: builder,
  );
}

/// Shared modal bottom sheet: handle, title, optional subtitle, Close, and body.
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder bodyBuilder,
  bool showClose = true,
  bool isScrollControlled = true,
  bool useRootNavigator = true,
}) {
  return presentAppModalSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    builder: (ctx) => AppModalSheet(
      title: title,
      subtitle: subtitle,
      showClose: showClose,
      child: bodyBuilder(ctx),
    ),
  );
}

/// Scrollable list region for [AppModalSheet].
///
/// Do not use [ListView] with [shrinkWrap] and [NeverScrollableScrollPhysics]
/// inside a modal sheet: [AppModalSheet] gives the body a bounded max height
/// via [Flexible], so a non-scrollable list is clipped with no way to scroll.
class AppModalSheetListBody extends StatelessWidget {
  const AppModalSheetListBody({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: children,
    );
  }
}

class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.showClose = true,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final bool showClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // SafeArea covers the system inset; viewInsets lifts content above the keyboard.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final styles = context.textStyles;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          AppSpacing.sm,
          AppMetrics.horizontalPadding,
          AppSpacing.md + keyboard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHandle(),
            Text(title, style: styles.titleSmall, textAlign: TextAlign.center),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: styles.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            SizedBox(height: AppSpacing.sm),
            Flexible(child: child),
            if (showClose) ...[
              SizedBox(height: AppSpacing.sm),
              AppCancelTextButton(
                label: l10n.actionClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
