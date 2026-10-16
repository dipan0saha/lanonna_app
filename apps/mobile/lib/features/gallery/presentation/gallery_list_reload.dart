import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/gallery_repository.dart';
import '../domain/gallery_loaded_pages.dart';
import '../data/models/photo_models.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';

/// Subscribes to [GalleryRepository] and reloads a photo list when gallery data changes.
///
/// Coalesces overlapping [ChangeNotifier] notifications so a refresh skipped while
/// one is in flight is scheduled again when it completes.
mixin GalleryListReload<T extends StatefulWidget> on State<T> {
  GalleryRepository? _galleryRepo;
  var _galleryRefreshQueued = false;
  var _incrementalRefreshInFlight = false;

  /// Baby id for the loaded list; return null to skip refresh.
  String? galleryReloadBabyId();

  /// Current loaded items (updated by [applyGalleryReloadResult]).
  List<PhotoSummary> get galleryReloadPhotos;

  /// API sort key (`default`, `recent`, `favorites`).
  String get galleryReloadSort;

  /// How many items are currently loaded (pagination offset).
  int get galleryReloadLoadedCount;

  /// Whether more pages exist beyond the loaded window.
  bool get galleryReloadHasMore;

  /// Apply a refreshed list from the API.
  void applyGalleryReloadResult(
    List<PhotoSummary> photos,
    int requestedCount, {
    bool? hasMore,
  });

  /// Whether a full-tab load is in progress (refresh waits until false).
  bool get galleryReloadBlockedByFullLoad;

  void registerGalleryListReload() {
    final repo = context.read<GalleryRepository>();
    if (_galleryRepo == repo) return;
    _galleryRepo?.removeListener(_onGalleryRepositoryChanged);
    _galleryRepo = repo;
    _galleryRepo!.addListener(_onGalleryRepositoryChanged);
  }

  void disposeGalleryListReload() {
    _galleryRepo?.removeListener(_onGalleryRepositoryChanged);
    _galleryRepo = null;
    _galleryRefreshQueued = false;
  }

  void _onGalleryRepositoryChanged() {
    if (galleryReloadBabyId() == null) return;
    if (_incrementalRefreshInFlight) {
      _galleryRefreshQueued = true;
      return;
    }
    unawaited(_refreshLoadedPhotos());
  }

  Future<void> refreshGalleryListNow() => _refreshLoadedPhotos();

  /// Call when the full-tab load finishes (success or failure). A change that
  /// arrived while the full load was in flight may not be in its response, so
  /// the queued incremental refresh runs now instead of being dropped.
  void onGalleryFullLoadSettled() {
    if (!_galleryRefreshQueued || !mounted) return;
    _galleryRefreshQueued = false;
    unawaited(_refreshLoadedPhotos());
  }

  Future<void> _refreshLoadedPhotos() async {
    if (_incrementalRefreshInFlight || galleryReloadBlockedByFullLoad) {
      _galleryRefreshQueued = true;
      return;
    }
    final babyId = galleryReloadBabyId();
    if (babyId == null) return;
    _incrementalRefreshInFlight = true;
    try {
      final loadedCount = galleryReloadPhotos.isEmpty
          ? GalleryRepository.pageSize
          : galleryReloadLoadedCount;
      final refresh = await refreshLoadedPhotoList(
        _galleryRepo!,
        babyId,
        currentItems: galleryReloadPhotos,
        loadedCount: loadedCount,
        previousHasMore: galleryReloadHasMore,
        sort: galleryReloadSort,
      );
      if (!mounted) return;
      applyGalleryReloadResult(
        refresh.items,
        refresh.loadedCount,
        hasMore: refresh.hasMore,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      _incrementalRefreshInFlight = false;
      if (_galleryRefreshQueued && mounted) {
        _galleryRefreshQueued = false;
        unawaited(_refreshLoadedPhotos());
      }
    }
  }
}
