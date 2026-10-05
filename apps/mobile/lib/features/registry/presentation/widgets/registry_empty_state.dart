import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class RegistryEmptyState extends StatelessWidget {
  const RegistryEmptyState({
    super.key,
    required this.isOwner,
    this.onAddItem,
  });

  final bool isOwner;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_outlined, size: 36, color: AppColors.primaryDark),
          const SizedBox(height: 12),
          Text('No registry items yet', style: context.textStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Add the things your baby will need so family knows what to bring.'
                : "Nothing's been added to the registry yet - check back soon.",
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (isOwner && onAddItem != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAddItem, child: const Text('+ Add Item')),
          ],
        ],
      ),
    );
  }
}
