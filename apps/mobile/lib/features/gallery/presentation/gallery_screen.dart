import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/data/parallel_requests.dart';
import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/presentation/tab_load_kind.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_caps_label.dart';
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
import 'gallery_list_reload.dart';
import 'widgets/gallery_empty_state.dart';
import 'widgets/gallery_photo_grid.dart';
import 'widgets/gallery_view_mode_selector.dart';
import '../../../l10n/app_localizations.dart';

enum GalleryViewMode { all, recent, favorites }

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.mode = GalleryViewMode.all});

  final GalleryViewMode mode;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with BabyContextReload, TabLoadGenerationCache, GalleryListReload {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  BabySummary? _baby;
  List<PhotoSummary> _photos = [];
  List<HomeActivityItem> _activity = [];
  String? _error;
  var _loading = true;
  var _loadingMore = false;
  var _hasMorePhotos = true;
  var _photoOffset = 0;
  var _uploading = false;
  final _scrollController = ScrollController();

  @override
  String? galleryReloadBabyId() => _baby?.id;

  @override
  List<PhotoSummary> get galleryReloadPhotos => _photos;

  @override
  String get galleryReloadSort => _apiSort;

  @override
  int get galleryReloadLoadedCount => _photoOffset;

  @override
  bool get galleryReloadHasMore => _hasMorePhotos;

  @override
  bool get galleryReloadBlockedByFullLoad => _loading;

  @override
  void applyGalleryReloadResult(
    List<PhotoSummary> photos,
    int requestedCount, {
    bool? hasMore,
  }) {
    setState(() {
      _photos = photos;
      _photoOffset = photos.length;
      if (hasMore != null) {
        _hasMorePhotos = hasMore;
      } else if (photos.length < requestedCount) {
        _hasMorePhotos = false;
      }
    });
  }

  bool get _isAllMode => widget.mode == GalleryViewMode.all;

  String get _apiSort => switch (widget.mode) {
    GalleryViewMode.all => 'default',
    GalleryViewMode.recent => 'recent',
    GalleryViewMode.favorites => 'favorites',
  };

  String get _sectionLabel => switch (widget.mode) {
    GalleryViewMode.all => l10n.galleryAllPhotos,
    GalleryViewMode.recent => l10n.galleryRecentActivity,
    GalleryViewMode.favorites => l10n.galleryFavorites,
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (!_hasMorePhotos || _loadingMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMorePhotos();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
    registerGalleryListReload();
  }

  @override
  void dispose() {
    disposeGalleryListReload();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  Future<void> _load() async {
    final store = context.read<SelectedBabyStore>();
    if (shouldShowTabLoadSpinner(
      store,
      hasDisplayedPayload: hasCurrentTabPayload(store, _baby?.id),
    )) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final homeRepo = context.read<HomeRepository>();
      final galleryRepo = context.read<GalleryRepository>();
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
      final (photoPage, activityPage) = await waitBoth(
        galleryRepo.listPhotosPage(baby.id, sort: _apiSort),
        _isAllMode
            ? homeRepo.fetchActivityPage(baby.id, limit: 20, scope: 'gallery')
            : Future<ActivityPage?>.value(null),
      );
      final activity = activityPage == null
          ? <HomeActivityItem>[]
          : activityPage.items.take(6).toList();
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _photos = photoPage.items;
        _photoOffset = photoPage.items.length;
        _hasMorePhotos = photoPage.hasMore;
        _activity = activity;
        _loading = false;
      });
      rememberTabLoadGeneration(store, baby);
      onGalleryFullLoadSettled();
    } catch (e) {
      if (!mounted) return;
      final hasPayload = hasCurrentTabPayload(store, _baby?.id);
      if (!hasPayload) {
        setState(() {
          _baby = null;
          _photos = [];
          _activity = [];
        });
      }
      reportTabLoadFailure(
        context,
        e,
        hasPayload: hasPayload,
        onBlockingError: (message) {
          setState(() {
            _error = message;
            _loading = false;
          });
        },
      );
      if (hasPayload && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onGridSignedUrlError() {
    unawaited(refreshGalleryListNow());
  }

  Future<void> _loadMorePhotos() async {
    final baby = _baby;
    if (baby == null || !_hasMorePhotos || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<GalleryRepository>().listPhotosPage(
        baby.id,
        sort: _apiSort,
        offset: _photoOffset,
      );
      if (!mounted) return;
      setState(() {
        _photos = [..._photos, ...page.items];
        _photoOffset += page.items.length;
        _hasMorePhotos = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackBar.showAlert(
        context,
        apiErrorMessage(AppLocalizations.of(context)!, e),
      );
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _onAddPhoto() async {
    final baby = _baby;
    if (baby == null || !_isOwner || _uploading) return;
    final file = await showPhotoSourceSheet(context);
    if (file == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final photoId = await runGalleryPhotoUpload(
        context: context,
        babyProfileId: baby.id,
        imageFile: file,
        gallery: context.read<GalleryRepository>(),
      );
      if (mounted) {
        notifyGalleryDataChanged(context);
        AppSnackBar.showInfo(context, l10n.galleryPhotoUploaded);
      }
      await _pollUntilReady(baby.id, photoId);
      if (mounted) {
        notifyGalleryDataChanged(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(
          context,
          l10n.galleryUploadFailed(
            apiErrorMessage(AppLocalizations.of(context)!, e),
          ),
        );
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
      final detail = await galleryRepo.fetchPhoto(babyId, photoId);
      if (detail.status == 'ready' && detail.thumbUrl != null) {
        return;
      }
    }
    if (mounted) {
      AppSnackBar.showAlert(context, l10n.galleryPhotoProcessingIsTakingLonger);
    }
  }

  Widget _buildFilteredEmpty() {
    return switch (widget.mode) {
      GalleryViewMode.recent => AppEmptyState(
        expand: false,
        icon: Icons.history,
        title: l10n.emptyRecentPhotos,
        message: l10n.emptyPhotosLast30,
      ),
      GalleryViewMode.favorites => AppEmptyState(
        expand: false,
        icon: Icons.favorite_border,
        title: l10n.emptyFavoritesYet,
        message: l10n.messageSquishPhotosLove,
      ),
      GalleryViewMode.all => const SizedBox.shrink(),
    };
  }

  bool get _showFab =>
      _isOwner && _baby != null && (_isAllMode ? _photos.isNotEmpty : true);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final headline = context.textStyles.headlineSmall;
    final store = context.read<SelectedBabyStore>();
    final kind = resolveTabLoadKind(
      loading: _loading,
      hasError: _error != null,
      hasPayload: hasCurrentTabPayload(store, _baby?.id),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShellTabLayout(
        onRefresh: _load,
        body: CustomScrollView(
          controller: _scrollController,
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
                // One tab title; the selector below names the view (#393).
                child: Text(l10n.notificationChannelGallery, style: headline),
              ),
            ),
            if (kind == TabLoadKind.loading || _baby != null)
              SliverToBoxAdapter(
                child: GalleryViewModeSelector(selected: widget.mode),
              ),
            if (kind == TabLoadKind.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (kind == TabLoadKind.error)
              SliverFillRemaining(
                child: AsyncTabBody(
                  loading: false,
                  error: _error,
                  onRetry: _load,
                  child: const SizedBox.shrink(),
                ),
              )
            else if (_baby == null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    l10n.actionCreateBabyProfileUse,
                    style: context.textStyles.bodyMedium,
                  ),
                ),
              )
            else if (_photos.isEmpty)
              SliverFillRemaining(
                child: _isAllMode
                    ? GalleryEmptyState(
                        isOwner: _isOwner,
                        babyName: _baby?.name,
                        onAddPhoto: _isOwner ? _onAddPhoto : null,
                      )
                    : _buildFilteredEmpty(),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.horizontalPadding,
                    0,
                    AppMetrics.horizontalPadding,
                    8,
                  ),
                  child: AppSectionCapsLabel(_sectionLabel),
                ),
              ),
              GalleryPhotoGrid(
                photos: _photos,
                onPhotoTap: (p) => context.push(
                  GalleryRoutes.photoDetail(p.id, sort: _apiSort),
                ),
                onSignedUrlError: _onGridSignedUrlError,
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else if (!_hasMorePhotos)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppMetrics.horizontalPadding,
                      8,
                      AppMetrics.horizontalPadding,
                      0,
                    ),
                    child: Text(
                      l10n.messageVeReachedEnd,
                      textAlign: TextAlign.center,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              if (_isAllMode) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppMetrics.horizontalPadding,
                      16,
                      AppMetrics.horizontalPadding,
                      8,
                    ),
                    child: AppSectionCapsLabel(l10n.galleryRecentActivity),
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
                tooltip: l10n.actionAddPhoto3,
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
              label: l10n.actionAddPhoto3,
            )
          : null,
    );
  }
}
