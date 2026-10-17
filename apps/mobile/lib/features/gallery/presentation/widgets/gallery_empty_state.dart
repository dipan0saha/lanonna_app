import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/domain/baby_display_label.dart';
import '../../../../core/widgets/app_empty_state.dart';

class GalleryEmptyState extends StatelessWidget {
  const GalleryEmptyState({
    super.key,
    required this.isOwner,
    required this.babyName,
    this.onAddPhoto,
  });

  final bool isOwner;
  final String babyName;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = babyDisplayName(babyName, l10n);
    return AppEmptyState(
      expand: false,
      icon: Icons.photo_outlined,
      title: l10n.emptyPhotosYet,
      message: isOwner
          ? 'Add your first photo to start sharing $name\'s journey with family.'
          : 'Once a photo is shared, it will show up here for everyone to enjoy.',
      actionLabel: isOwner ? '+ Add Photo' : null,
      onAction: onAddPhoto,
    );
  }
}
