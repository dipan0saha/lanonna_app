import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_cancel_text_button.dart';
import 'app_sheet_handle.dart';

/// Shared modal bottom sheet: handle, title, optional subtitle, Close, and body.
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder bodyBuilder,
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
    builder: (ctx) => AppModalSheet(
      title: title,
      subtitle: subtitle,
      child: bodyBuilder(ctx),
    ),
  );
}

class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final styles = context.textStyles;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          AppSpacing.sm,
          AppMetrics.horizontalPadding,
          AppSpacing.md + bottom,
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
            child,
            SizedBox(height: AppSpacing.sm),
            AppCancelTextButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
