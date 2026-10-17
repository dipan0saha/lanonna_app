import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../domain/rsvp_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_semantics.dart';

/// Three equal-width RSVP tiles (Going / Maybe / Can't go).
class AppRsvpTileRow extends StatelessWidget {
  const AppRsvpTileRow({
    super.key,
    required this.selectedStatus,
    required this.onSelect,
    this.enabled = true,
  });

  final RsvpStatus? selectedStatus;
  final ValueChanged<RsvpStatus> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        for (final (i, status) in RsvpStatus.values.indexed) ...[
          if (i > 0) SizedBox(width: AppSpacing.sm),
          Expanded(child: _tile(context, status, status.label(l10n))),
        ],
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    RsvpStatus value,
    String label,
  ) {
    final selected = selectedStatus == value;
    final style = context.textStyles.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: selected ? AppColors.primaryDark : AppColors.textPrimary,
    );
    final child = Material(
      color: selected ? AppColors.sageTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.selectTileRadius),
        side: BorderSide(
          color: selected ? AppColors.primaryDark : AppColors.border,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: enabled ? () => onSelect(value) : null,
        borderRadius: BorderRadius.circular(AppMetrics.selectTileRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppMetrics.selectTileVerticalPadding,
          ),
          child: Center(
            child: Text(label, style: style, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
    return AppSemantics.button(
      'rsvp_${value.apiValue}',
      child,
      label: label,
    );
  }
}
