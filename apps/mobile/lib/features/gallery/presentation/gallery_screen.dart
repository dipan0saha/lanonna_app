import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/models/home_summary.dart';
import '../../home/data/selected_baby_store.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../onboarding/data/models/baby_summary.dart';
import '../data/gallery_repository.dart';
import '../data/models/photo_models.dart';
import '../domain/gallery_routes.dart';
import 'sheets/photo_source_sheet.dart';
import 'widgets/gallery_activity_section.dart';
import 'widgets/gallery_empty_state.dart';
import 'widgets/gallery_photo_grid.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  BabySummary? _baby;
  List<PhotoSummary> _photos = [];
  List<HomeActivityItem> _activity = [];
  String? _error;
  var _loading = true;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      final photos = await galleryRepo.listPhotos(baby.id);
      HomeSummary? summary;
      if (baby.role == 'owner') {
        summary = await homeRepo.fetchHomeSummary(baby.id);
      }
      setState(() {
        _baby = baby;
        _photos = photos;
        _activity = summary?.recentActivity ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
      final upload = DisplayPhotoUpload(context.read<ApiClient>());
      await upload.uploadGalleryPhoto(
        babyProfileId: baby.id,
        imageFile: file,
      );
      await _pollUntilReady(baby.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pollUntilReady(String babyId) async {
    final galleryRepo = context.read<GalleryRepository>();
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final photos = await galleryRepo.listPhotos(babyId);
      if (photos.any((p) => p.status == 'ready' && p.thumbUrl != null)) {
        return;
      }
    }
  }

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
                  child: Text('Gallery', style: headline),
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
                  child: Center(child: Text(_error!)),
                )
              else if (_photos.isEmpty)
                SliverFillRemaining(
                  child: GalleryEmptyState(
                    isOwner: _isOwner,
                    onAddPhoto: _isOwner ? _onAddPhoto : null,
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'All Photos',
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
                  ),
                ),
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
                  child: GalleryActivitySection(items: _activity),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ],
          ),
        ),
      floatingActionButton: _isOwner && _baby != null && _photos.isNotEmpty
          ? FloatingActionButton(
              key: const Key('upload_photo_fab'),
              onPressed: _uploading ? null : _onAddPhoto,
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            )
          : null,
    );
  }
}
