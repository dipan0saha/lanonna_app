import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../domain/registry_item_sort.dart';

class RegistrySortControl extends StatelessWidget {
  const RegistrySortControl({
    super.key,
    required this.sort,
    required this.onChanged,
  });

  final RegistryItemSort sort;
  final ValueChanged<RegistryItemSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(sort.toggled),
      borderRadius: BorderRadius.circular(AppMetrics.fieldRadius),
      child: Padding(
        padding: AppMetrics.sortControlPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.menuLabel,
              style: context.textStyles.labelMedium?.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }
}
