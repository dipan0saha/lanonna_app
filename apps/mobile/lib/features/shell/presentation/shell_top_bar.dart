import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/baby_display_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/account_repository.dart';
import '../../account/data/notifications_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/domain/app_routes.dart';
import '../../home/presentation/widgets/home_top_bar.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import 'baby_switcher_sheet.dart';

Widget shellHomeTopBar(BuildContext context) {
  return const _ShellTopBar();
}

/// Shell invite action: owner baby required before batch invite.
Future<void> onShellInviteFamilyTap(BuildContext context) async {
  final store = context.read<SelectedBabyStore>();
  final baby = await context.read<HomeRepository>().resolveOwnerBaby(store);
  if (!context.mounted) return;
  if (baby == null) {
    await showShellInviteRequiresOwnerBabyDialog(context);
    return;
  }
  await context.push(AppRoutes.inviteFamily);
}

Future<void> showShellInviteRequiresOwnerBabyDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final addBaby = await showConfirmDialog(
    context,
    title: l10n.shellInviteRequiresOwnerBabyTitle,
    message: l10n.shellInviteRequiresOwnerBabyMessage,
    confirmLabel: l10n.actionAddBaby,
  );
  if (addBaby && context.mounted) {
    context.push('/baby/create');
  }
}

/// The shell top bar: a view over shared state, so the five tab copies cost
/// no requests. Title from [SelectedBabyStore], bell dot from
/// [NotificationsRepository.unread], avatar from [AccountRepository]; all are
/// kept current once for the whole shell by `ShellChromeSync`.
class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SelectedBabyStore>();
    final notificationsRepo = context.read<NotificationsRepository>();
    final accountRepo = context.read<AccountRepository>();
    final l10n = AppLocalizations.of(context)!;
    // The selected baby's name as last resolved from the server (kept by
    // SelectedBabyStore so it survives an offline cold start).
    final title = store.hasResolvedSelectedBaby
        ? babyNameLabel(l10n, store.selectedBabyName)
        : null;
    return ListenableBuilder(
      listenable: Listenable.merge([
        notificationsRepo.unread,
        accountRepo.profileUpdates,
      ]),
      builder: (context, _) {
        // Last known identity, so the avatar keeps the right initials (and
        // cached photo) when the profile cannot load, e.g. offline.
        final identity = accountRepo.identity;
        return HomeTopBar(
          centerTitle: title,
          showUnreadDot: notificationsRepo.unread.count > 0,
          onAddBabyTap: () => context.push('/baby/create'),
          onInviteFamilyTap: () => onShellInviteFamilyTap(context),
          onBabySwitcherTap: () => showBabySwitcherSheet(context),
          onNotificationsTap: () async {
            await context.push('/notifications/inbox');
            try {
              await notificationsRepo.refreshUnreadCount();
            } catch (e) {
              debugPrint('shell_top_bar_unread_refresh_failed: $e');
            }
          },
          onAccountTap: () => context.push('/profile'),
          accountDisplayName: identity?.displayName,
          accountFallbackText: identity?.email,
          accountAvatarUrl: identity?.avatarUrl,
        );
      },
    );
  }
}
