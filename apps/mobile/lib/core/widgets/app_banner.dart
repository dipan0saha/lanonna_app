import 'package:flutter/material.dart';

import '../theme/la_nonna_theme.dart';

/// The app's inline banner (a themed [MaterialBanner]): an optional bold
/// [title] above the [message], an optional leading [icon], and actions.
///
/// Used for Home system announcements (title + body from the API) and the
/// Home load-error banner, so every banner shares one layout.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    this.title,
    required this.message,
    required this.actions,
    this.icon,
  });

  final String? title;
  final String message;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final heading = title?.trim() ?? '';
    return MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading.isNotEmpty) ...[
            Text(
              heading,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (message.isNotEmpty) const SizedBox(height: AppSpacing.xxs),
          ],
          if (message.isNotEmpty) Text(message, style: text.bodyMedium),
        ],
      ),
      leading: icon == null ? null : Icon(icon),
      actions: actions,
    );
  }
}
