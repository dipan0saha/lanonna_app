import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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

  final String? selectedStatus;
  final ValueChanged<String> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tile(context, 'going', 'Going', 'rsvp_going')),
        const SizedBox(width: 8),
        Expanded(child: _tile(context, 'maybe', 'Maybe', 'rsvp_maybe')),
        const SizedBox(width: 8),
        Expanded(child: _tile(context, 'cant_go', "Can't go", 'rsvp_cant_go')),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String value,
    String label,
    String semanticsId,
  ) {
    final selected = selectedStatus == value;
    final style = context.textStyles.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: selected ? AppColors.primaryDark : AppColors.textPrimary,
    );
    final child = Material(
      color: selected ? AppColors.sageTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primaryDark : AppColors.border,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: enabled ? () => onSelect(value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: Text(label, style: style, textAlign: TextAlign.center)),
        ),
      ),
    );
    return AppSemantics.button(semanticsId, child, label: label);
  }
}
