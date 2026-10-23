import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/gallery_routes.dart';
import '../gallery_screen.dart';

/// Routes between `/gallery`, `/gallery/recent`, and `/gallery/favorites`.
class GalleryViewModeSelector extends StatelessWidget {
  const GalleryViewModeSelector({super.key, required this.selected});

  final GalleryViewMode selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        12,
      ),
      child: SegmentedButton<GalleryViewMode>(
        segments: [
          ButtonSegment(
            value: GalleryViewMode.all,
            label: Text(l10n.galleryAllPhotos),
          ),
          ButtonSegment(
            value: GalleryViewMode.recent,
            label: Text(l10n.labelRecentPhotos),
          ),
          ButtonSegment(
            value: GalleryViewMode.favorites,
            label: Text(l10n.galleryFavorites),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (modes) {
          final mode = modes.first;
          if (mode == selected) return;
          final route = switch (mode) {
            GalleryViewMode.all => GalleryRoutes.gallery,
            GalleryViewMode.recent => GalleryRoutes.recent,
            GalleryViewMode.favorites => GalleryRoutes.favorites,
          };
          context.go(route);
        },
      ),
    );
  }
}
