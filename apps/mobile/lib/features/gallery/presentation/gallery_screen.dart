import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_semantics.dart';
import 'upload/run_gallery_photo_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../../home/data/models/home_summary.dart';
import '../../../core/widgets/activity/activity_feed_card.dart';
import '../../home/data/selected_baby_store.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/gallery_repository.dart';
import '../domain/gallery_refresh.dart';
import '../data/models/photo_models.dart';
import '../domain/gallery_routes.dart';
import 'sheets/photo_source_sheet.dart';
import 'widgets/gallery_empty_state.dart';
import 'widgets/gallery_photo_grid.dart';

enum GalleryViewMode { all, recent, favorites }

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.mode = GalleryViewMode.all});

  final GalleryViewMode mode;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with BabyContextReload {
  BabySummary? _baby;
  List<PhotoSummary> _photos = [];
  List<HomeActivityItem> _activity = [];
  String? _error;
  var _loading = true;
  var _uploading = false;
  GalleryRepository? _galleryRepo;

  bool get _isAllMode => widget.mode == GalleryViewMode.all;

  String get _apiSort => switch (widget.mode) {
        GalleryViewMode.all => 'default',
        GalleryViewMode.recent => 'recent',
        GalleryViewMode.favorites => 'favorites',
      };

  String get _pageTitle => switch (widget.mode) {
        GalleryViewMode.all => 'Gallery',
        GalleryViewMode.recent => 'Recent Photos',
        GalleryViewMode.favorites => 'Favorites',
      };

  String get _sectionLabel => switch (widget.mode) {
        GalleryViewMode.all => 'All Photos',
        GalleryViewMode.recent => 'Last 30 days',
        GalleryViewMode.favorites => 'Most squished',
      };

  @override
  void initState() {
    super.initState();
    _galleryRepo = context.read<GalleryRepository>();
    _galleryRepo!.addListener(_onGalleryChanged);
    _load();
  }

  void _onGalleryChanged() => _load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    _galleryRepo?.removeListener(_onGalleryChanged);
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeRepo = context.read<HomeRepository>();
      final galleryRepo = context.read<GalleryRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() {
          _baby = null;
          _photos = [];
          _activity = [];
          _loading = false;
        });
        return;
      }
      final photosFuture = galleryRepo.listPhotos(baby.id, sort: _apiSort);
      final activityFuture = _isAllMode
          ? homeRepo.fetchActivityPage(
              baby.id,
              limit: 20,
              scope: 'gallery',
            )
          : Future.value(null);
      final photos = await photosFuture;
      final activityPage = await activityFuture;
      final activity = activityPage == null
          ? <HomeActivityItem>[]
          : activityPage.items.take(6).toList();
      setState(() {
        _baby = baby;
        _photos = photos;
        _activity = activity;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _onAddPhoto() async {
    final baby = _baby;
    if (baby == null || !_isOwner || _uploading) return;
    final file = await showPhotoSourceSheet(context);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final photoId = await runGalleryPhotoUpload(
        context: context,
        babyProfileId: baby.id,
        imageFile: file,
        api: context.read<ApiClient>(),
      );
      if (mounted) {
        notifyGalleryDataChanged(context);
        AppSnackBar.showInfo(context, 'Photo uploaded');
      }
      await _pollUntilReady(baby.id, photoId);
      if (mounted) {
        notifyGalleryDataChanged(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pollUntilReady(String babyId, String photoId) async {
    final galleryRepo = context.read<GalleryRepository>();
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final photos = await galleryRepo.listPhotos(babyId);
      PhotoSummary? match;
      for (final p in photos) {
        if (p.id == photoId) {
          match = p;
          break;
        }
      }
      if (match != null &&
          match.status == 'ready' &&
          match.thumbUrl != null) {
        return;
      }
    }
  }

  Widget _buildFilteredEmpty() {
    final message = switch (widget.mode) {
      GalleryViewMode.recent =>
        'No photos in the last 30 days. Upload a new moment or browse the full gallery.',
      GalleryViewMode.favorites =>
        'No favorites yet. Squish photos you love and they will show up here.',
      GalleryViewMode.all => '',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ),
    );
  }

  bool get _showFab =>
      _isOwner &&
      _baby != null &&
      (_isAllMode ? _photos.isNotEmpty : true);

  @override
  Widget build(BuildContext context) {
    final headline = context.textStyles.headlineSmall;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShellTabLayout(
        onRefresh: _load,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppMetrics.horizontalPadding,
                  0,
                  AppMetrics.horizontalPadding,
                  10,
                ),
                child: Text(_pageTitle, style: headline),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_baby == null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Create a baby profile to use Gallery.',
                    style: context.textStyles.bodyMedium,
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: AsyncTabBody(
                  loading: false,
                  error: _error,
                  onRetry: _load,
                  child: const SizedBox.shrink(),
                ),
              )
            else if (_photos.isEmpty)
              SliverFillRemaining(
                child: _isAllMode
                    ? GalleryEmptyState(
                        isOwner: _isOwner,
                        onAddPhoto: _isOwner ? _onAddPhoto : null,
                      )
                    : _buildFilteredEmpty(),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _sectionLabel,
                    style: context.textStyles.labelLarge?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: GalleryPhotoGrid(
                  photos: _photos,
                  onPhotoTap: (p) =>
                      context.push(GalleryRoutes.photoDetail(p.id)),
                  onSignedUrlError: _load,
                ),
              ),
              if (_isAllMode) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Recent Activity',
                      style: context.textStyles.labelLarge?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ActivityFeedCard(
                    items: _activity,
                    showEmptyState: true,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? AppSemantics.button(
              'gallery_upload_fab',
              FloatingActionButton(
                key: const Key('upload_photo_fab'),
                onPressed: _uploading ? null : _onAddPhoto,
                child: _uploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
            )
          : null,
    );
  }
}
