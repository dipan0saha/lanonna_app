import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/comments/comment_actions.dart';
import '../../../core/comments/comment_composer_controller.dart';
import '../../../core/presentation/detail_screen_load.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/input/dismiss_text_input.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_engagement_pill.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/detail_comment_composer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/gallery_repository.dart';
import '../data/photo_comment_thread.dart';
import '../data/models/photo_models.dart';
import '../domain/gallery_navigation.dart';
import '../domain/gallery_refresh.dart';
import '../domain/gallery_routes.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photoId,
    this.gallerySort = 'default',
  });

  final String photoId;
  final String gallerySort;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  BabySummary? _baby;
  PhotoDetail? _detail;
  List<String> _photoIds = [];
  var _photoIdPageOffset = 0;
  var _photoIdListHasMore = true;
  var _photoIdListLoading = false;
  var _initialLoadInFlight = true;
  final _scrollController = ScrollController();
  var _editingCaption = false;
  final _captionFocus = FocusNode();
  var _signedUrlRetried = false;
  var _savingTags = false;
  List<BabySummary> _memberBabies = [];
  Set<String> _taggedBabyIds = {};
  final _captionController = TextEditingController();
  late final CommentComposerController _comments;

  @override
  void initState() {
    super.initState();
    _comments = CommentComposerController(
      port: PhotoCommentThread(
        repository: context.read<GalleryRepository>(),
        babyId: () => _baby?.id,
        photoId: () => widget.photoId,
      ),
      onPosted: () async {
        await _refreshPhotoDetail(scrollToComments: true);
        if (mounted) notifyGalleryDataChanged(context);
      },
      onError: (error) {
        if (mounted) _showApiError(error);
      },
    );
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant PhotoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      dismissTextInputFocus(_captionFocus);
      _editingCaption = false;
      _signedUrlRetried = false;
      _comments.textController.clear();
      _comments.unfocus();
      setState(() {
        _detail = null;
        _photoIds = [];
        _photoIdPageOffset = 0;
        _photoIdListHasMore = true;
        _initialLoadInFlight = true;
      });
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _captionFocus.dispose();
    _captionController.dispose();
    _comments.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _initialLoadInFlight = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() => _initialLoadInFlight = false);
        return;
      }
      if (!mounted) return;
      final galleryRepo = context.read<GalleryRepository>();
      final detail = await galleryRepo.fetchPhoto(baby.id, widget.photoId);
      _captionController.text = detail.caption ?? '';
      final memberBabies = baby.role == 'owner'
          ? await homeRepo.listBabies()
          : <BabySummary>[];
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _detail = detail;
        _memberBabies = memberBabies;
        _taggedBabyIds = detail.taggedBabies.map((t) => t.id).toSet();
        _initialLoadInFlight = false;
      });
      unawaited(_ensurePhotoIdsForSwipe());
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoadInFlight = false);
      if (e is ApiException && e.statusCode == 404) {
        AppSnackBar.showAlert(context, 'This photo is no longer available.');
        returnToGallery(context);
        return;
      }
      AppSnackBar.showAlert(context, apiErrorMessage(e));
    }
  }

  Future<void> _appendPhotoIdPage() async {
    final baby = _baby;
    if (baby == null || !_photoIdListHasMore || _photoIdListLoading) return;
    _photoIdListLoading = true;
    try {
      final page = await context.read<GalleryRepository>().listPhotosPage(
        baby.id,
        sort: widget.gallerySort,
        offset: _photoIdPageOffset,
      );
      if (!mounted) return;
      setState(() {
        _photoIds = [..._photoIds, ...page.items.map((p) => p.id)];
        _photoIdPageOffset += page.items.length;
        _photoIdListHasMore = page.hasMore;
      });
    } finally {
      _photoIdListLoading = false;
    }
  }

  Future<void> _ensurePhotoIdsForSwipe() async {
    while (mounted &&
        _photoIdListHasMore &&
        !_photoIds.contains(widget.photoId)) {
      await _appendPhotoIdPage();
    }
    var idx = _photoIds.indexOf(widget.photoId);
    while (mounted &&
        _photoIdListHasMore &&
        idx >= 0 &&
        idx >= _photoIds.length - 1) {
      await _appendPhotoIdPage();
      idx = _photoIds.indexOf(widget.photoId);
    }
  }

  Future<void> _ensurePhotoIdForAdjacent(int delta) async {
    final idx = _photoIds.indexOf(widget.photoId);
    if (idx < 0) return;
    final target = idx + delta;
    while (mounted && target >= _photoIds.length && _photoIdListHasMore) {
      await _appendPhotoIdPage();
    }
  }

  Future<void> _refreshPhotoDetail({bool scrollToComments = false}) async {
    final baby = _baby;
    if (baby == null) return;
    try {
      final detail = await context.read<GalleryRepository>().fetchPhoto(
        baby.id,
        widget.photoId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        if (!_editingCaption) {
          _captionController.text = detail.caption ?? '';
        }
        _taggedBabyIds = detail.taggedBabies.map((t) => t.id).toSet();
      });
      if (scrollToComments) {
        _scrollToBottom();
      }
    } catch (e) {
      _showApiError(e);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _beginCaptionEdit() {
    setState(() => _editingCaption = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editingCaption) return;
      _captionFocus.requestFocus();
    });
  }

  bool get _isOwner => _baby?.role == 'owner';

  void _showApiError(Object e) {
    if (!mounted) return;
    AppSnackBar.showAlert(context, apiErrorMessage(e));
  }

  Future<void> _saveCaption() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    final caption = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _captionController.text,
    );
    try {
      await context.read<GalleryRepository>().updateCaption(
        baby.id,
        detail.id,
        caption.isEmpty ? null : caption,
      );
      dismissTextInputFocus(_captionFocus);
      setState(() {
        _editingCaption = false;
        _detail = detail.copyWith(caption: caption.isEmpty ? null : caption);
      });
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _toggleSquish() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    final wasSquished = detail.viewerHasSquished;
    try {
      final squished = await context.read<GalleryRepository>().toggleSquish(
        baby.id,
        detail.id,
      );
      if (!mounted) return;
      final delta = squished == wasSquished
          ? 0
          : squished
          ? 1
          : -1;
      setState(() {
        _detail = detail.copyWith(
          viewerHasSquished: squished,
          squishCount: detail.squishCount + delta,
        );
      });
      notifyGalleryDataChanged(context);
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _editComment(PhotoComment comment) async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !comment.canEdit) return;
    final text = await showEditCommentDialog(context, comment.body);
    if (text == null || !mounted) return;
    try {
      await context.read<GalleryRepository>().updateComment(
        baby.id,
        detail.id,
        comment.id,
        text,
      );
      await _refreshPhotoDetail();
    } catch (e) {
      if (mounted) showCommentError(context, e);
    }
  }

  Future<void> _savePhotoTags() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !_isOwner || _savingTags) return;
    setState(() => _savingTags = true);
    try {
      final tagged = await context.read<GalleryRepository>().setPhotoTags(
        baby.id,
        detail.id,
        _taggedBabyIds.toList(),
      );
      if (mounted) {
        setState(() {
          _taggedBabyIds = tagged.map((t) => t.id).toSet();
        });
      }
    } catch (e) {
      _showApiError(e);
    } finally {
      if (mounted) setState(() => _savingTags = false);
    }
  }

  void _onDisplayUrlError() {
    if (_signedUrlRetried) return;
    _signedUrlRetried = true;
    _refreshPhotoDetail();
  }

  Future<void> _deleteComment(PhotoComment comment) async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !comment.canDelete) return;
    final ok = await confirmDeleteComment(context);
    if (!ok || !mounted) return;
    try {
      await context.read<GalleryRepository>().deleteComment(
        baby.id,
        detail.id,
        comment.id,
      );
      await _refreshPhotoDetail();
      if (mounted) notifyGalleryDataChanged(context);
    } catch (e) {
      if (mounted) showCommentError(context, e);
    }
  }

  Future<void> _deletePhoto() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !_isOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.photoDeleteConfirmTitle),
        content: Text(AppLocalizations.of(context)!.messageRemoves),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!mounted) return;
      await context.read<GalleryRepository>().deletePhoto(baby.id, detail.id);
      if (mounted) {
        notifyGalleryDataChanged(context);
        context.pop();
      }
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _goAdjacent(int delta) async {
    await _ensurePhotoIdForAdjacent(delta);
    if (!mounted) return;
    final idx = _photoIds.indexOf(widget.photoId);
    if (idx < 0) return;
    final next = idx + delta;
    if (next < 0 || next >= _photoIds.length) return;
    context.replace(
      GalleryRoutes.photoDetail(_photoIds[next], sort: widget.gallerySort),
    );
  }

  bool get _hasPreviousPhoto => _photoIds.indexOf(widget.photoId) > 0;

  bool get _hasNextPhoto {
    final idx = _photoIds.indexOf(widget.photoId);
    if (idx < 0) return false;
    return idx < _photoIds.length - 1 || _photoIdListHasMore;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = context.textStyles;
    if (shouldShowDetailFullScreenLoader(
      hasContent: _detail != null,
      initialLoadInFlight: _initialLoadInFlight,
    )) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context)!.photoNotFound)),
      );
    }
    final meta = formatApiCalendarDateFromParts(
      detail.createdAt,
      localeNameForFormatting(context),
    );
    final baby = _baby;
    final currentBabyId = baby?.id;
    return PrototypeSubpageScaffold(
      title: l10n.eventPhotoLabel,
      actions: [
        if (_isOwner)
          AppIconButton(
            semanticsId: 'photo_delete',
            label: l10n.actionDeletePhoto,
            onPressed: _deletePhoto,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 20,
            ),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey<String>('photo-detail-${widget.photoId}'),
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (detail.displayUrl != null)
                          CachedSignedImage(
                            imageUrl: detail.displayUrl,
                            cacheKey: 'display-${widget.photoId}',
                            fit: BoxFit.cover,
                            onSignedUrlError: _onDisplayUrlError,
                          )
                        else
                          ColoredBox(
                            color: Colors.grey.shade300,
                            child: Center(child: Text(AppLocalizations.of(context)!.photoProcessing)),
                          ),
                        if (_hasPreviousPhoto)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: AppSpacing.md,
                            child: Center(
                              child: _PhotoHeroNavButton(
                                semanticsId: 'photo_previous',
                                label: l10n.actionPreviousPhoto,
                                icon: Icons.keyboard_arrow_up,
                                onPressed: () => unawaited(_goAdjacent(-1)),
                              ),
                            ),
                          ),
                        if (_hasNextPhoto)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: AppSpacing.md,
                            child: Center(
                              child: _PhotoHeroNavButton(
                                semanticsId: 'photo_next',
                                label: l10n.actionNextPhoto,
                                icon: Icons.keyboard_arrow_down,
                                onPressed: () => unawaited(_goAdjacent(1)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: AppMetrics.subpageScrollPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_editingCaption && _isOwner)
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  kind: AppTextInputKind.prose,
                                  controller: _captionController,
                                  focusNode: _captionFocus,
                                  autofocus: false,
                                  decoration: InputDecoration(
                                    hintText: l10n.actionAddCaption,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _saveCaption,
                                child: Text(AppLocalizations.of(context)!.actionSave),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  detail.caption ?? 'No caption',
                                  style: styles.titleSmall,
                                ),
                              ),
                              if (_isOwner)
                                AppIconButton(
                                  semanticsId: 'photo_caption_edit',
                                  label: l10n.actionEditCaption,
                                  onPressed: _beginCaptionEdit,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        Text(
                          'Uploaded $meta by ${detail.uploaderDisplayName}',
                          style: styles.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppSquishEngagementPill(
                              semanticsId: 'gallery_photo_squish',
                              label: l10n.photoSquishCount(detail.squishCount),
                              active: detail.viewerHasSquished,
                              onPressed: _toggleSquish,
                            ),
                            AppEngagementPill(
                              label: l10n.photoCommentCount(
                                detail.comments.length,
                              ),
                              icon: Icons.chat_bubble_outline,
                            ),
                          ],
                        ),
                        if (_isOwner &&
                            currentBabyId != null &&
                            _memberBabies.any(
                              (b) => b.id != currentBabyId,
                            )) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.labelPhoto,
                            style: styles.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final b in _memberBabies)
                                if (b.id != currentBabyId)
                                  AppToggleChip(
                                    label: b.name,
                                    selected: _taggedBabyIds.contains(b.id),
                                    onTap: () {
                                      setState(() {
                                        if (_taggedBabyIds.contains(b.id)) {
                                          _taggedBabyIds.remove(b.id);
                                        } else {
                                          _taggedBabyIds.add(b.id);
                                        }
                                      });
                                      _savePhotoTags();
                                    },
                                  ),
                            ],
                          ),
                        ] else if (detail.taggedBabies.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'In this photo: ${detail.taggedBabies.map((t) => t.name).join(', ')}',
                            style: styles.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          l10n.announcementCommentsHeading,
                          style: styles.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (var i = 0; i < detail.comments.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.comments[i].authorDisplayName,
                                        style: styles.labelMedium,
                                      ),
                                      if (i == detail.comments.length - 1)
                                        AppSemantics.button(
                                          'gallery_comment_latest',
                                          Text(
                                            detail.comments[i].body,
                                            style: styles.bodyMedium,
                                          ),
                                          label: detail.comments[i].body,
                                        )
                                      else
                                        Text(
                                          detail.comments[i].body,
                                          style: styles.bodyMedium,
                                        ),
                                    ],
                                  ),
                                ),
                                if (detail.comments[i].canEdit ||
                                    detail.comments[i].canDelete)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (detail.comments[i].canEdit)
                                        AppIconButton(
                                          semanticsId: 'photo_comment_edit',
                                          label: l10n.commentEditTitle,
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _editComment(detail.comments[i]),
                                        ),
                                      if (detail.comments[i].canDelete)
                                        AppIconButton(
                                          semanticsId: 'photo_comment_delete',
                                          label: l10n.commentDeleteMenuLabel,
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () => _deleteComment(
                                            detail.comments[i],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          DetailCommentComposer(
            controller: _comments,
            semanticsId: 'gallery_photo_comment',
            sendSemanticsId: 'gallery_comment_send',
          ),
        ],
      ),
    );
  }
}

class _PhotoHeroNavButton extends StatelessWidget {
  const _PhotoHeroNavButton({
    required this.semanticsId,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String semanticsId;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppSemantics.button(
      semanticsId,
      Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: AppMetrics.photoNavButtonElevation,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              icon,
              color: AppColors.textPrimary,
              size: AppMetrics.trailingIconSize,
            ),
          ),
        ),
      ),
      label: label,
    );
  }
}
