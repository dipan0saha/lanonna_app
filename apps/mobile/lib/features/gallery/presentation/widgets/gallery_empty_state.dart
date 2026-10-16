import 'package:flutter/material.dart';

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
    final name = babyName.trim().isEmpty ? 'your baby' : babyName.trim();
    return AppEmptyState(
      expand: false,
      icon: Icons.photo_outlined,
      title: 'No photos yet',
      message: isOwner
          ? 'Add your first photo to start sharing $name\'s journey with family.'
          : 'Once a photo is shared, it will show up here for everyone to enjoy.',
      actionLabel: isOwner ? '+ Add Photo' : null,
      onAction: onAddPhoto,
    );
  }
}
