import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../gallery/domain/gallery_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';
import 'home_upcoming_events_section.dart';
import '../../../../l10n/app_localizations.dart';

class HomeTeasersSection extends StatelessWidget {
  const HomeTeasersSection({
    super.key,
    required this.teasers,
    this.onSignedUrlError,
    this.includeUpcomingEvents = true,
  });

  final HomeTeasers teasers;
  final VoidCallback? onSignedUrlError;
  final bool includeUpcomingEvents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];

    if (includeUpcomingEvents && teasers.upcomingEvents.isNotEmpty) {
      children.add(HomeUpcomingEventsSection(events: teasers.upcomingEvents));
    }

    if (teasers.recentPhotos.isNotEmpty) {
      children.add(
        HomeScrollSection(
          title: l10n.labelRecentPhotos,
          trailing: HomeSectionLink(
            label: l10n.actionView,
            onPressed: () => context.go(GalleryRoutes.recent),
          ),
          body: _photoRow(
            teasers.recentPhotos,
            onSignedUrlError: onSignedUrlError,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _photoRow(
    List<HomeTeaserPhoto> photos, {
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
          return AppSemantics.button(
            'home_recent_photo_${p.id}',
            GestureDetector(
              onTap: () => context.push('/gallery/photo/${p.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.thumbUrl != null
                    ? CachedSignedImage(
                        imageUrl: p.thumbUrl,
                        cacheKey: photoThumbCacheKey(p.id),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        onSignedUrlError: onSignedUrlError,
                      )
                    : Container(
                        width: 88,
                        height: 88,
                        color: AppColors.sageTint,
                        child: const Icon(Icons.photo_outlined),
                      ),
              ),
            ),
            label: AppLocalizations.of(context)!.actionOpenPhoto,
          );
        },
      ),
    );
  }
}
