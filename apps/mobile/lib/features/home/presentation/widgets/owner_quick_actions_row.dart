import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class OwnerQuickActionsRow extends StatelessWidget {
  const OwnerQuickActionsRow({
    super.key,
    required this.onAddPhoto,
    required this.onAddEvent,
    required this.onRegistry,
  });

  final VoidCallback onAddPhoto;
  final VoidCallback onAddEvent;
  final VoidCallback onRegistry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: _Action(
              label: 'Add Photo',
              icon: Icons.photo_camera_outlined,
              onTap: onAddPhoto,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Action(
              label: 'Add Event',
              icon: Icons.calendar_today_outlined,
              onTap: onAddEvent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Action(
              label: 'Registry',
              icon: Icons.card_giftcard_outlined,
              onTap: onRegistry,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(height: 6),
            Text(label, style: context.textStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}
