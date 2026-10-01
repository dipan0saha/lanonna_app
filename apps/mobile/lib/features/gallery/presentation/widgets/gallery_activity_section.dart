import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../home/data/models/home_summary.dart';

class GalleryActivitySection extends StatelessWidget {
  const GalleryActivitySection({super.key, required this.items});

  final List<HomeActivityItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final styles = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.summary,
                        style: styles.bodyMedium,
                      ),
                    ),
                    Text(
                      _shortDate(item.createdAt),
                      style:
                          styles.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return '${_month(dt.month)} ${dt.day}';
  }

  String _month(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }
}
