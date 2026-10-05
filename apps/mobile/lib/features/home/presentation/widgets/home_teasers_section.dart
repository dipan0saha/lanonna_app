import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/router/deep_link_navigation.dart';
import '../../../calendar/domain/calendar_routes.dart';
import '../../../gallery/domain/gallery_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_section_header.dart';
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
    final children = <Widget>[];

    if (teasers.notificationPreview.isNotEmpty) {
      children.add(const HomeSectionHeader(title: 'Notifications'));
      children.add(
        _CardList(
          items: teasers.notificationPreview
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
      );
    }

    if (teasers.upcomingEvents.isNotEmpty) {
      children.add(HomeUpcomingEventsSection(events: teasers.upcomingEvents));
    }

    if (teasers.rsvpReminders.isNotEmpty) {
      children.add(const HomeSectionHeader(title: 'RSVP Reminders'));
      children.add(
        _CardList(
          items: teasers.rsvpReminders
              .map(
                (e) => ListTile(
                  title: Text(e.title),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push(CalendarRoutes.eventDetail(e.id)),
                ),
              )
              .toList(),
        ),
      );
    }

    if (teasers.recentPhotos.isNotEmpty) {
      children.add(
        HomeSectionHeader(
          title: 'Recent Photos',
          action: TextButton(
            onPressed: () => context.go(GalleryRoutes.recent),
            child: const Text('View all'),
          ),
        ),
      );
      children.add(_photoRow(teasers.recentPhotos, AppColors.sageTint, onSignedUrlError: onSignedUrlError));
    }

    if (teasers.favoritePhotos.isNotEmpty) {
      children.add(
        HomeSectionHeader(
          title: 'Gallery Favorites',
          action: TextButton(
            onPressed: () => context.go(GalleryRoutes.favorites),
            child: const Text('View all'),
          ),
        ),
      );
      children.add(_photoRow(
        teasers.favoritePhotos,
        AppColors.peachTint,
        favorites: true,
        onSignedUrlError: onSignedUrlError,
      ));
    }

    if (teasers.registryOpenCount > 0 && teasers.registryHighlights.isEmpty) {
      children.add(const HomeSectionHeader(title: 'Registry Highlights'));
      children.add(
        _CardList(
          items: [
            ListTile(
              title: Text('${teasers.registryOpenCount} items still needed'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.go('/registry'),
            ),
          ],
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
    return Column(
      children: [
        SizedBox(
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
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        12,
      ),
      child: Column(children: items),
    );
  }
}
