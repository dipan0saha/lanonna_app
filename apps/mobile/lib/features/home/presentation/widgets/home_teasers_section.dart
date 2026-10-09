import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/router/deep_link_navigation.dart';
import '../../../calendar/domain/calendar_routes.dart';
import '../../../gallery/domain/gallery_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';
import 'home_upcoming_events_section.dart';

class HomeTeasersSection extends StatelessWidget {
  const HomeTeasersSection({
    super.key,
    required this.teasers,
    this.onSignedUrlError,
  });

  final HomeTeasers teasers;
  final VoidCallback? onSignedUrlError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];

    if (teasers.notificationPreview.isNotEmpty) {
      children.add(
        HomeScrollSection.bordered(
          title: 'Notifications',
          padding: EdgeInsets.zero,
          child: Column(
            children: teasers.notificationPreview
                .map(
                  (n) => ListTile(
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: n.deepLink != null && n.deepLink!.isNotEmpty
                        ? const Icon(Icons.chevron_right, color: AppColors.muted)
                        : null,
                    onTap: n.deepLink != null && n.deepLink!.isNotEmpty
                        ? () => navigateAppDeepLink(context, n.deepLink)
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    if (teasers.upcomingEvents.isNotEmpty) {
      children.add(HomeUpcomingEventsSection(events: teasers.upcomingEvents));
    }

    if (teasers.rsvpReminders.isNotEmpty) {
      children.add(
        HomeScrollSection.bordered(
          title: 'RSVP Reminders',
          padding: EdgeInsets.zero,
          child: Column(
            children: teasers.rsvpReminders
                .map(
                  (e) => ListTile(
                    title: Text(e.title),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: () => context.push(CalendarRoutes.eventDetail(e.id)),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    if (teasers.recentPhotos.isNotEmpty) {
      children.add(
        HomeScrollSection(
          title: 'Recent Photos',
          trailing: HomeSectionLink(
            label: 'View all',
            onPressed: () => context.go(GalleryRoutes.recent),
          ),
          body: _photoRow(
            teasers.recentPhotos,
            AppColors.sageTint,
            onSignedUrlError: onSignedUrlError,
          ),
        ),
      );
    }

    if (teasers.favoritePhotos.isNotEmpty) {
      children.add(
        HomeScrollSection(
          title: 'Gallery Favorites',
          trailing: HomeSectionLink(
            label: 'View all',
            onPressed: () => context.go(GalleryRoutes.favorites),
          ),
          body: _photoRow(
            teasers.favoritePhotos,
            AppColors.peachTint,
            favorites: true,
            onSignedUrlError: onSignedUrlError,
          ),
        ),
      );
    }

    if (teasers.registryOpenCount > 0 && teasers.registryHighlights.isEmpty) {
      children.add(
        HomeScrollSection.bordered(
          title: 'Registry Highlights',
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(l10n.registryItemsStillNeeded(teasers.registryOpenCount)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.go('/registry'),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _photoRow(
    List<HomeTeaserPhoto> photos,
    Color fallback, {
    bool favorites = false,
    VoidCallback? onSignedUrlError,
  }) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = photos[i];
          return GestureDetector(
            onTap: () => context.push(
              favorites ? GalleryRoutes.photoDetail(p.id) : '/gallery/photo/${p.id}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: p.thumbUrl != null
                  ? CachedSignedImage(
                      imageUrl: p.thumbUrl,
                      cacheKey: 'thumb-${p.id}',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      onSignedUrlError: onSignedUrlError,
                    )
                  : Container(
                      width: 88,
                      height: 88,
                      color: fallback,
                      child: Icon(
                        favorites ? Icons.favorite_outline : Icons.photo_outlined,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
