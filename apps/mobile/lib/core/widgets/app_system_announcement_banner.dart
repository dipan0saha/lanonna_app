import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Dismissible system announcement on Home (API `system_announcements`).
class AppSystemAnnouncementBanner extends StatelessWidget {
  const AppSystemAnnouncementBanner({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.semanticsLabel,
  });

  final String title;
  final String body;
  final List<Widget> actions;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final titleStyle = text.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final bodyStyle = text.bodyMedium;
    final label = semanticsLabel ?? _combinedLabel(title, body);

    return MaterialBanner(
      content: Semantics(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty) Text(title, style: titleStyle),
            if (title.isNotEmpty && body.isNotEmpty)
              const SizedBox(height: AppSpacing.xxs),
            if (body.isNotEmpty) Text(body, style: bodyStyle),
          ],
        ),
      ),
      leading: const Icon(Icons.campaign_outlined),
      actions: actions,
    );
  }

  static String _combinedLabel(String title, String body) {
    if (title.isEmpty) return body;
    if (body.isEmpty) return title;
    return '$title. $body';
  }
}
