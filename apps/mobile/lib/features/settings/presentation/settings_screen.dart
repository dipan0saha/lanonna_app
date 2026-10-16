import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/platform/external_link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import 'biometric_unlock_settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openHelp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: const {'subject': 'La Nonna support'},
    );
    await openExternalLink(
      context,
      uri,
      failureMessage:
          'Could not open email to ${AppConfig.supportEmail}. Copy link?',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PrototypeSubpageScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        padding: AppMetrics.subpageScrollPadding,
        children: [
          const BiometricUnlockSettingsTile(),
          AppSemantics.button(
            'settings_notifications',
            ListTile(
              title: Text(l10n.settingsNotifications),
              subtitle: Text(l10n.settingsNotificationsSubtitle),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.push('/account/notification-preferences'),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsEditProfile),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.push('/account/edit'),
          ),
          ListTile(
            title: Text(l10n.settingsHelpSupport),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => _openHelp(context),
          ),
        ],
      ),
    );
  }
}
