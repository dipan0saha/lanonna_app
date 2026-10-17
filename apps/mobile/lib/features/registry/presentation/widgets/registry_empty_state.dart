import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../l10n/app_localizations.dart';

class RegistryEmptyState extends StatelessWidget {
  const RegistryEmptyState({
    super.key,
    required this.isOwner,
    this.onAddItem,
  });

  final bool isOwner;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppEmptyState(
      expand: false,
      icon: Icons.card_giftcard_outlined,
      title: l10n.registryEmptyTitle,
      message: isOwner
          ? AppLocalizations.of(context)!.registryAddTheThingsYourBaby
          : AppLocalizations.of(context)!.registryNothingsBeenAddedToThe,
      actionLabel: isOwner ? AppLocalizations.of(context)!.registryAddItemCta : null,
      onAction: onAddItem,
    );
  }
}
