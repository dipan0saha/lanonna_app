import 'package:flutter/material.dart';

import '../domain/baby_gender.dart';
import '../domain/baby_summary.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Baby list avatar: gender emoji when known (prototype baby thumb).
class BabyProfileAvatar extends StatelessWidget {
  const BabyProfileAvatar({super.key, required this.baby, this.size});

  final BabySummary baby;
  final double? size;

  static String emojiForBaby(BabySummary baby) => switch (baby.gender) {
        BabyGender.female => '👧',
        BabyGender.male => '👦',
        BabyGender.unknown => '👶',
      };

  @override
  Widget build(BuildContext context) {
    final fontSize = size ?? AppMetrics.memberLeadingEmojiSize;
    return Text(
      emojiForBaby(baby),
      style: context.textStyles.headlineSmall?.copyWith(fontSize: fontSize),
    );
  }
}
