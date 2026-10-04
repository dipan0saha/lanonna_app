import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class AccountProfileCard extends StatelessWidget {
  const AccountProfileCard({
    super.key,
    required this.initials,
    required this.displayName,
    this.email,
    required this.onEdit,
    required this.onLogOut,
  });

  final String initials;
  final String displayName;
  final String? email;
  final VoidCallback onEdit;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.sageTint,
              child: Text(initials, style: text.titleLarge),
            ),
            const SizedBox(height: 12),
            Text(displayName, style: text.titleMedium),
            if (email != null) ...[
              const SizedBox(height: 4),
              Text(
                email!,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Edit Profile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppSemantics.button(
                    'account_sign_out',
                    OutlinedButton(
                      onPressed: onLogOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Log Out'),
                    ),
                    label: 'Log Out',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
