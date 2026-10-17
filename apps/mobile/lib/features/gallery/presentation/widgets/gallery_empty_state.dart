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
          ? AppLocalizations.of(context)!.galleryAddYourFirstPhotoTo(name)
          : AppLocalizations.of(context)!.galleryOnceAPhotoIsShared,
      actionLabel: isOwner ? AppLocalizations.of(context)!.galleryAddPhoto : null,
      onAction: onAddPhoto,
    );
  }
}
