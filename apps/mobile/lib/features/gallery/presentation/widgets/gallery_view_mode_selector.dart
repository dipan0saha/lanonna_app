import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/gallery_routes.dart';
import '../gallery_screen.dart';

/// All / Recent / Favorites switcher under the Gallery title (#393). Each
/// mode is its own route (`/gallery`, `/gallery/recent`, `/gallery/favorites`)
/// backed by the photo list `sort` (`default`, `recent`, `favorites`).
class GalleryViewModeSelector extends StatelessWidget {
  const GalleryViewModeSelector({super.key, required this.selected});

  final GalleryViewMode selected;

  static String routeFor(GalleryViewMode mode) => switch (mode) {
    GalleryViewMode.all => GalleryRoutes.gallery,
    GalleryViewMode.recent => GalleryRoutes.recent,
    GalleryViewMode.favorites => GalleryRoutes.favorites,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppToggleChipBar<GalleryViewMode>(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        12,
      ),
      options: [
        AppToggleChipOption(GalleryViewMode.all, l10n.galleryAllPhotos),
        AppToggleChipOption(GalleryViewMode.recent, l10n.labelRecentPhotos),
        AppToggleChipOption(GalleryViewMode.favorites, l10n.galleryFavorites),
      ],
      selected: selected,
      onSelected: (mode) {
        if (mode != selected) context.go(routeFor(mode));
      },
    );
  }
}
