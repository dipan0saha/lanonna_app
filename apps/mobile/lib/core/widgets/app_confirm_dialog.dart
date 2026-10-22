import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_responsive_button_pair.dart';

/// Standard vs error-filled primary confirm (prototype `#confirmOverlay` danger button).
enum ConfirmDialogVariant { standard, destructive }

/// One step in [showConfirmDialogSequence] (e.g. delete-baby two-step flow).
class ConfirmDialogStep {
  const ConfirmDialogStep({
    required this.title,
    this.message,
    required this.confirmLabel,
    this.variant = ConfirmDialogVariant.standard,
    this.cancelLabel,
    this.typedConfirmationPhrase,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final ConfirmDialogVariant variant;
  final String? cancelLabel;

  /// When set, user must type this exact string before confirm is enabled.
  final String? typedConfirmationPhrase;
}

/// Shows a confirmation dialog. Returns `true` only when the user taps confirm.
///
/// Barrier dismiss and cancel return `false` (same as prior `showDialog<bool>` + `== true` checks).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  ConfirmDialogVariant variant = ConfirmDialogVariant.standard,
  bool barrierDismissible = true,
  String? typedConfirmationPhrase,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: variant,
      typedConfirmationPhrase: typedConfirmationPhrase,
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
      cancelLabel: step.cancelLabel,
      variant: step.variant,
      typedConfirmationPhrase: step.typedConfirmationPhrase,
    );
    if (!ok || !context.mounted) return false;
  }
  return true;
}

class AppConfirmDialog extends StatefulWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.variant = ConfirmDialogVariant.standard,
    this.typedConfirmationPhrase,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String? cancelLabel;
  final ConfirmDialogVariant variant;
  final String? typedConfirmationPhrase;

  @override
  State<AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<AppConfirmDialog> {
  final _typedController = TextEditingController();

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  bool get _confirmEnabled {
    final phrase = widget.typedConfirmationPhrase;
    if (phrase == null || phrase.isEmpty) return true;
    return _typedController.text == phrase;
  }

  ButtonStyle _confirmStyle(BuildContext context) {
    if (widget.variant != ConfirmDialogVariant.destructive) {
      return FilledButton.styleFrom(
        minimumSize: const Size(
          AppMetrics.buttonMinWidth,
          AppMetrics.buttonMinHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.buttonHorizontalPadding,
          vertical: AppMetrics.buttonVerticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      minimumSize: const Size(
        AppMetrics.buttonMinWidth,
        AppMetrics.buttonMinHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.buttonHorizontalPadding,
        vertical: AppMetrics.buttonVerticalPadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cancel = widget.cancelLabel ?? l10n.actionCancel;
    final titleStyle = context.textStyles.titleMedium;
    final bodyStyle = context.textStyles.bodyMedium;

    final buttonRow = AppResponsiveButtonPair(
      start: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancel),
      ),
      end: FilledButton(
        style: _confirmStyle(context),
        onPressed:
            _confirmEnabled ? () => Navigator.of(context).pop(true) : null,
        child: Text(widget.confirmLabel),
      ),
    );

    final hasBody =
        widget.message != null || widget.typedConfirmationPhrase != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(widget.title, style: titleStyle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) Text(widget.message!, style: bodyStyle),
          if (widget.typedConfirmationPhrase != null) ...[
            if (widget.message != null) const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _typedController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.typedConfirmationPhrase,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (hasBody) const SizedBox(height: AppSpacing.lg),
          buttonRow,
        ],
      ),
    );
  }
}
