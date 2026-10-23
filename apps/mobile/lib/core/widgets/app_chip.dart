import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

enum AppChipAccent { sage, peach, neutral }

class _ChipColors {
  const _ChipColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_ChipColors _filledAccentColors(AppChipAccent accent) {
  switch (accent) {
    case AppChipAccent.peach:
      return const _ChipColors(
        background: AppColors.peachTint,
        border: AppColors.secondaryDark,
        foreground: AppColors.secondaryDark,
      );
    case AppChipAccent.sage:
    case AppChipAccent.neutral:
      return const _ChipColors(
        background: AppColors.sageTint,
        border: AppColors.primaryDark,
        foreground: AppColors.primaryDark,
      );
  }
}

_ChipColors _toggleColors({
  required bool selected,
  required AppChipAccent selectedAccent,
}) {
  if (!selected) {
    return const _ChipColors(
      background: AppColors.surface,
      border: AppColors.muted,
      foreground: AppColors.textPrimary,
    );
  }
  return _filledAccentColors(selectedAccent);
}

/// Selectable pill (RSVP, AI tabs, presets, photo tags).
class AppToggleChip extends StatelessWidget {
  const AppToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedAccent = AppChipAccent.sage,
    this.showPlusPrefix = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AppChipAccent selectedAccent;
  final bool showPlusPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = _toggleColors(
      selected: selected,
      selectedAccent: selectedAccent,
    );
    final text = showPlusPrefix ? '+ $label' : label;
    final style = context.textStyles.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.appChipHorizontalPadding,
        vertical: AppMetrics.appChipVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        border: Border.all(
          color: colors.border,
          width: AppMetrics.appChipBorderWidth,
        ),
      ),
      child: Text(text, style: style),
    );

    if (onTap == null) {
      return Opacity(opacity: 0.5, child: child);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// One option in an [AppToggleChipBar].
class AppToggleChipOption<T> {
  const AppToggleChipOption(
    this.value,
    this.label, {
    this.chipKey,
    this.selectedAccent = AppChipAccent.sage,
  });

  final T value;
  final String label;

  /// Optional key on the underlying [AppToggleChip] (tests, scroll targets).
  final Key? chipKey;

  /// Fill used when this option is selected (e.g. peach for Girl).
  final AppChipAccent selectedAccent;
}

/// A horizontal, scrollable row of [AppToggleChip]s with one selected value:
/// the app's view switcher (AI suggestion tabs, gallery All / Recent /
/// Favorites, Fun Names / Predictions). Use it instead of Material chips or
/// `SegmentedButton`. Tapping the already-selected option is a no-op, so
/// callers only see real changes.
class AppToggleChipBar<T> extends StatelessWidget {
  const AppToggleChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(
      AppMetrics.horizontalPadding,
      AppSpacing.lg,
      AppMetrics.horizontalPadding,
      AppSpacing.lg,
    ),
  });

  final List<AppToggleChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: AppToggleChip(
                key: option.chipKey,
                label: option.label,
                selected: option.value == selected,
                selectedAccent: option.selectedAccent,
                onTap: () {
                  if (option.value != selected) onSelected(option.value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Filled pill with remove control (e.g. first-moment name suggestions).
class AppRemovableChip extends StatelessWidget {
  const AppRemovableChip({
    super.key,
    required this.label,
    required this.accent,
    required this.onRemove,
    this.enabled = true,
  });

  final String label;
  final AppChipAccent accent;
  final VoidCallback? onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = _filledAccentColors(accent);
    final labelStyle = context.textStyles.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );
    final canRemove = enabled && onRemove != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.only(
        left: AppMetrics.appChipHorizontalPadding,
        right: 6,
        top: AppMetrics.appChipVerticalPadding,
        bottom: AppMetrics.appChipVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        border: Border.all(
          color: colors.border,
          width: AppMetrics.appChipBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 4),
          Semantics(
            button: canRemove,
            label: AppLocalizations.of(context)!.chipRemoveSemantics(label),
            child: GestureDetector(
              onTap: canRemove ? onRemove : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: colors.foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
