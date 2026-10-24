import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_modal_sheet.dart';
import 'app_semantics.dart';
import 'app_responsive_button_pair.dart';

/// Primary confirm look: standard (sage) or error-filled for irreversible
/// deletes/removals (prototype `#confirmOverlay` danger button).
enum ConfirmDialogVariant { standard, destructive }

/// One step in [showConfirmDialogSequence] (e.g. delete-baby two-step flow).
class ConfirmDialogStep {
  const ConfirmDialogStep({
    required this.title,
    this.message,
    required this.confirmLabel,
    this.variant = ConfirmDialogVariant.standard,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final ConfirmDialogVariant variant;
}

/// App-wide confirmation: the prototype `#confirmOverlay` bottom sheet
/// (handle, title, muted message, outline Cancel + filled confirm).
///
/// Returns `true` only when the user taps confirm; Cancel, swipe-down and
/// barrier taps return `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  ConfirmDialogVariant variant = ConfirmDialogVariant.standard,
}) async {
  final result = await presentAppModalSheet<bool>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: variant,
    ),
  );
  return result == true;
}

/// Runs [steps] in order; stops at the first decline or dismiss.
Future<bool> showConfirmDialogSequence(
  BuildContext context,
  List<ConfirmDialogStep> steps,
) async {
  for (final step in steps) {
    final ok = await showConfirmDialog(
      context,
      title: step.title,
      message: step.message,
      confirmLabel: step.confirmLabel,
      variant: step.variant,
    );
    if (!ok || !context.mounted) return false;
  }
  return true;
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.variant = ConfirmDialogVariant.standard,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String? cancelLabel;
  final ConfirmDialogVariant variant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = this.message;
    return AppModalSheet(
      title: title,
      showClose: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The message scrolls so a long body (e.g. delete-account's list of
          // profiles) never pushes the actions off-screen.
          if (message != null && message.trim().isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _ConfirmActions(
            cancelLabel: cancelLabel ?? l10n.actionCancel,
            confirmLabel: confirmLabel,
            variant: variant,
          ),
        ],
      ),
    );
  }
}

/// Outline Cancel + filled confirm, side by side like the prototype when both
/// labels fit on one line at half width; otherwise stacked so a long label
/// (e.g. "Mark as purchased") never wraps inside a squeezed button.
class _ConfirmActions extends StatelessWidget {
  const _ConfirmActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.variant,
  });

  final String cancelLabel;
  final String confirmLabel;
  final ConfirmDialogVariant variant;

  double _buttonWidth(BuildContext context, String label) {
    final theme = Theme.of(context);
    final style =
        theme.elevatedButtonTheme.style?.textStyle?.resolve({}) ??
        theme.textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 2 * AppMetrics.buttonHorizontalPadding;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSpacing.smMd;
        final half = (constraints.maxWidth - gap) / 2;
        final fitsSideBySide =
            _buttonWidth(context, cancelLabel) <= half &&
            _buttonWidth(context, confirmLabel) <= half;
        return AppResponsiveButtonPair(
          spacing: gap,
          breakpoint: fitsSideBySide ? 0 : double.infinity,
          start: AppSemantics.button(
            'app_confirm_dialog_cancel',
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ),
          // ElevatedButton carries the theme's primary CTA metrics, so both
          // halves of the pair share size, padding and shape.
          end: AppSemantics.button(
            'app_confirm_dialog_confirm',
            ElevatedButton(
              style: variant == ConfirmDialogVariant.destructive
                  ? AppButtonStyles.primaryDestructive
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ),
        );
      },
    );
  }
}
