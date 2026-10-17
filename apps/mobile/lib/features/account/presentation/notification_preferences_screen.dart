import 'package:flutter/material.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../../core/domain/baby_display_label.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../data/notifications_repository.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen>
    with BabyContextReload {
  NotificationPreferences? _prefs;
  var _loading = true;
  var _saving = false;
  String? _babyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  Future<void> _load() async {
    final prefs = await context
        .read<NotificationsRepository>()
        .fetchPreferences();
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    setState(() {
      _prefs = prefs;
      _babyName = baby?.name;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() => _saving = true);
    try {
      final updated = await context
          .read<NotificationsRepository>()
          .updatePreferences(
            digest: prefs.digest,
            pushEnabled: prefs.pushEnabled,
            emailDigestEnabled: prefs.emailDigestEnabled,
            notifyGalleryEnabled: prefs.notifyGalleryEnabled,
            notifyCalendarEnabled: prefs.notifyCalendarEnabled,
            notifyRegistryEnabled: prefs.notifyRegistryEnabled,
            notifyCommentsEnabled: prefs.notifyCommentsEnabled,
          );
      setState(() => _prefs = updated);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = _prefs;
    final babyLabel = babyDisplayName(l10n, _babyName);
    return PrototypeSubpageScaffold(
      title: l10n.notificationPrefsTitle,
      body: _loading || prefs == null
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppMetrics.subpageScrollPadding,
              children: [
                Text(
                  l10n.notificationPreferencesIntro(babyLabel),
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.messageChangeTime,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                AppSectionTitle(
                  title: AppLocalizations.of(
                    context,
                  )!.notificationPrefsFrequencyTitle(babyLabel),
                  style: context.textStyles.titleSmall,
                ),
                for (final digest in NotificationDigest.values)
                  _digestTile(digest, prefs),
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)!.notificationPrefsPushTitle,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.notificationPrefsPushSubtitle,
                  ),
                  value: prefs.pushEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(pushEnabled: v)),
                ),
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)!.notificationPrefsDigestTitle,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.notificationPrefsDigestSubtitle,
                  ),
                  value: prefs.emailDigestEnabled,
                  onChanged: (v) => setState(
                    () => _prefs = prefs.copyWith(emailDigestEnabled: v),
                  ),
                ),
                const SizedBox(height: AppMetrics.sectionBlockSpacing),
                AppSectionTitle(
                  title: l10n.notificationPrefsChannelsTitle,
                  style: context.textStyles.titleSmall,
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelGallery),
                  subtitle: Text(l10n.notificationChannelGallerySubtitle),
                  value: prefs.notifyGalleryEnabled,
                  onChanged: (v) => setState(
                    () => _prefs = prefs.copyWith(notifyGalleryEnabled: v),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelCalendar),
                  subtitle: Text(l10n.notificationChannelCalendarSubtitle),
                  value: prefs.notifyCalendarEnabled,
                  onChanged: (v) => setState(
                    () => _prefs = prefs.copyWith(notifyCalendarEnabled: v),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelRegistry),
                  subtitle: Text(l10n.notificationChannelRegistrySubtitle),
                  value: prefs.notifyRegistryEnabled,
                  onChanged: (v) => setState(
                    () => _prefs = prefs.copyWith(notifyRegistryEnabled: v),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelComments),
                  subtitle: Text(l10n.notificationChannelCommentsSubtitle),
                  value: prefs.notifyCommentsEnabled,
                  onChanged: (v) => setState(
                    () => _prefs = prefs.copyWith(notifyCommentsEnabled: v),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? l10n.notificationPrefsSaving
                        : l10n.notificationPrefsSave,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _digestTile(NotificationDigest value, NotificationPreferences prefs) {
    final selected = prefs.digest == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.primaryDark : AppColors.muted,
      ),
      title: Text(value.label(AppLocalizations.of(context)!)),
      onTap: () => setState(() => _prefs = prefs.copyWith(digest: value)),
    );
  }
}
