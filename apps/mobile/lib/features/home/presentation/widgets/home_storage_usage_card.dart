import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/home_summary.dart';

class HomeStorageUsageCard extends StatelessWidget {
  const HomeStorageUsageCard({super.key, required this.usage});

  final HomeStorageUsage usage;

  String _formatGb(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 0.1) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Storage', style: text.labelLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_formatGb(usage.usedBytes)} of ${_formatGb(usage.quotaBytes)} used',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: usage.usedFraction,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
