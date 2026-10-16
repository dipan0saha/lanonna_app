import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_gift_pill_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/registry_priority_chip.dart';
import '../../data/models/registry_models.dart';

class RegistryNeededRow extends StatelessWidget {
  const RegistryNeededRow({
    super.key,
    required this.item,
    required this.isOwner,
    required this.currentUid,
    this.onClaim,
    this.onEdit,
    this.onDelete,
  });

  final RegistryItem item;
  final bool isOwner;
  final String? currentUid;
  final VoidCallback? onClaim;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: context.textStyles.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null && item.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.description!,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    SizedBox(height: AppSpacing.xs),
                    RegistryPriorityChip(priority: item.priority),
                  ],
                ),
              ),
              if (isOwner) ...[
                AppIconButton(
                  semanticsId: 'registry_item_edit_${item.id}',
                  label: 'Edit item',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: AppMetrics.inlineIconSize,
                  ),
                ),
                AppIconButton(
                  semanticsId: 'registry_item_delete_${item.id}',
                  label: 'Delete item',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: AppMetrics.inlineIconSize,
                    color: AppColors.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          if (onClaim != null) ...[
            SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: AppGiftPillButton(
                semanticsId: isOwner
                    ? 'registry_mark_purchased'
                    : 'registry_claim_item',
                label: isOwner ? 'Mark as purchased' : "I'll buy this",
                onPressed: onClaim,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
            AppSemantics.button(
              'registry_undo_purchase',
              TextButton(onPressed: onUndo, child: const Text('Undo')),
              label: 'Undo purchase',
            ),
        ],
      ),
    );
  }
}
