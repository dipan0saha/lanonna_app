import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// In-body back row + title (prototype subpages without AppBar).
class PrototypeSubpageScaffold extends StatelessWidget {
  const PrototypeSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                4,
                AppMetrics.horizontalPadding,
                8,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.textStyles.titleMedium,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: actions!)
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
