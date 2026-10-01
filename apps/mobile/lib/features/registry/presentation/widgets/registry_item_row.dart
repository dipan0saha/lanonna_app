import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/registry_models.dart';

class RegistryNeededRow extends StatelessWidget {
  const RegistryNeededRow({
    super.key,
    required this.item,
    required this.isOwner,
    required this.currentUid,
    this.onBuy,
    this.onEdit,
    this.onDelete,
  });

  final RegistryItem item;
  final bool isOwner;
  final String? currentUid;
  final VoidCallback? onBuy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.textStyles.titleSmall),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                Text(
                  'Priority ${item.priority}',
                  style: context.textStyles.labelSmall?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          if (!isOwner && onBuy != null)
            TextButton(onPressed: onBuy, child: const Text("I'll buy this")),
          if (isOwner) ...[
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class RegistryPurchasedRow extends StatelessWidget {
  const RegistryPurchasedRow({
    super.key,
    required this.item,
    required this.canUndo,
    this.onUndo,
  });

  final RegistryItem item;
  final bool canUndo;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final purchase = item.purchase;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: context.textStyles.titleSmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.muted,
                  ),
                ),
                if (purchase != null)
                  Text(
                    'Purchased by ${purchase.purchaserDisplayName}',
                    style: context.textStyles.bodySmall,
                  ),
              ],
            ),
          ),
          if (canUndo && onUndo != null)
            TextButton(onPressed: onUndo, child: const Text('Undo')),
        ],
      ),
    );
  }
}
