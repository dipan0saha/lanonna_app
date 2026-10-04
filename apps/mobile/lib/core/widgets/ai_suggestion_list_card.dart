import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

class AiSuggestionTab {
  const AiSuggestionTab({required this.key, required this.label});

  final String key;
  final String label;
}

class AiSuggestionListItem {
  const AiSuggestionListItem({
    required this.title,
    required this.description,
    required this.onAdd,
    this.semanticsIdentifier,
  });

  final String title;
  final String description;
  final VoidCallback onAdd;
  final String? semanticsIdentifier;
}

/// Prototype `.card` + `.ai-item-row` list for calendar/registry AI suggestions.
class AiSuggestionListCard extends StatelessWidget {
  const AiSuggestionListCard({super.key, required this.items});

  final List<AiSuggestionListItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                AiSuggestionRow(item: items[i]),
                if (i < items.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AiSuggestionRow extends StatelessWidget {
  const AiSuggestionRow({super.key, required this.item});

  final AiSuggestionListItem item;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final addButton = Material(
      color: AppColors.sageTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: item.onAdd,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            '+ Add',
            style: text.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryButtonForeground,
            ),
          ),
        ),
      ),
    );

    final addControl = item.semanticsIdentifier != null
        ? Semantics(
            identifier: item.semanticsIdentifier,
            button: true,
            child: addButton,
          )
        : addButton;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          addControl,
        ],
      ),
    );
  }
}
