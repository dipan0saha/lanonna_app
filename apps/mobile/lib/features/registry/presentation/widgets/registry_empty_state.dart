import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';

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
    return AppEmptyState(
      expand: false,
      icon: Icons.card_giftcard_outlined,
      title: 'No registry items yet',
      message: isOwner
          ? 'Add the things your baby will need so family knows what to bring.'
          : "Nothing's been added to the registry yet — check back soon.",
      actionLabel: isOwner ? '+ Add Item' : null,
      onAction: onAddItem,
    );
  }
}
