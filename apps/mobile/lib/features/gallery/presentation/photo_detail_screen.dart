import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/presentation/detail_screen_load.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/gallery_repository.dart';
import '../data/models/photo_models.dart';
import '../domain/gallery_navigation.dart';
import '../domain/gallery_refresh.dart';
import '../domain/gallery_routes.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({super.key, required this.photoId});

  final String photoId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  BabySummary? _baby;
  PhotoDetail? _detail;
  List<String> _photoIds = [];
  var _initialLoadInFlight = true;
  final _scrollController = ScrollController();
  var _editingCaption = false;
  var _signedUrlRetried = false;
  var _savingTags = false;
  List<BabySummary> _memberBabies = [];
  Set<String> _taggedBabyIds = {};
  final _captionController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant PhotoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _editingCaption = false;
      _signedUrlRetried = false;
      _commentController.clear();
      setState(() {
        _detail = null;
        _initialLoadInFlight = true;
      });
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _captionController.dispose();
    _commentController.dispose();
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
      final photos = await galleryRepo.listPhotos(baby.id);
      final detail = await galleryRepo.fetchPhoto(baby.id, widget.photoId);
      _captionController.text = detail.caption ?? '';
      final memberBabies = baby.role == 'owner'
          ? await homeRepo.listBabies()
          : <BabySummary>[];
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _detail = detail;
        _photoIds = photos.map((p) => p.id).toList();
        _memberBabies = memberBabies;
        _taggedBabyIds = detail.taggedBabies.map((t) => t.id).toSet();
        _initialLoadInFlight = false;
      });
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

  Future<void> _refreshPhotoDetail({bool scrollToComments = false}) async {
    final baby = _baby;
    if (baby == null) return;
    try {
      final detail = await context
          .read<GalleryRepository>()
          .fetchPhoto(baby.id, widget.photoId);
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
      setState(() {
        _editingCaption = false;
        _detail = detail.copyWith(
          caption: caption.isEmpty ? null : caption,
        );
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
      final squished = await context
          .read<GalleryRepository>()
          .toggleSquish(baby.id, detail.id);
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

  Future<void> _addComment() async {
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _commentController.text,
    );
    if (text.isEmpty) return;
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    try {
      await context.read<GalleryRepository>().addComment(
        baby.id,
        detail.id,
        text,
      );
      _commentController.clear();
      await _refreshPhotoDetail(scrollToComments: true);
      if (mounted) notifyGalleryDataChanged(context);
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _editComment(PhotoComment comment) async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !comment.canEdit) return;
    final controller = TextEditingController(text: comment.body);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: AppTextField(
          kind: AppTextInputKind.prose,
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Comment'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) {
      controller.dispose();
      return;
    }
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      controller.text,
    );
    controller.dispose();
    if (text.isEmpty) return;
    try {
      if (!mounted) return;
      await context.read<GalleryRepository>().updateComment(
        baby.id,
        detail.id,
        comment.id,
        text,
      );
      await _refreshPhotoDetail();
    } catch (e) {
      _showApiError(e);
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!mounted) return;
      await context.read<GalleryRepository>().deleteComment(
        baby.id,
        detail.id,
        comment.id,
      );
      await _refreshPhotoDetail();
      if (mounted) notifyGalleryDataChanged(context);
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _deletePhoto() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !_isOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
          'This removes it for everyone who can see it - this can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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

  void _goAdjacent(int delta) {
    final idx = _photoIds.indexOf(widget.photoId);
    if (idx < 0) return;
    final next = idx + delta;
    if (next < 0 || next >= _photoIds.length) return;
    context.replace(GalleryRoutes.photoDetail(_photoIds[next]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = context.textStyles;
    if (shouldShowDetailFullScreenLoader(
      hasContent: _detail != null,
      initialLoadInFlight: _initialLoadInFlight,
    )) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Photo not found')),
      );
    }
    final meta = _formatDate(detail.createdAt);
    final baby = _baby;
    final currentBabyId = baby?.id;
    return PrototypeSubpageScaffold(
      title: 'Photo',
      actions: [
        if (_photoIds.length > 1) ...[
          IconButton(
            onPressed: () => _goAdjacent(-1),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          IconButton(
            onPressed: () => _goAdjacent(1),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
        if (_isOwner)
          IconButton(
            onPressed: _deletePhoto,
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
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
                            child: const Center(child: Text('Processing…')),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                                  decoration: const InputDecoration(
                                    hintText: 'Add a caption…',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _saveCaption,
                                child: const Text('Save'),
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
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _editingCaption = true),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
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
                        Row(
                          children: [
                            AppSemantics.button(
                              'gallery_photo_squish',
                              OutlinedButton.icon(
                                onPressed: _toggleSquish,
                                icon: Icon(
                                  detail.viewerHasSquished
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                                label: Text(l10n.photoSquishCount(detail.squishCount)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.photoCommentCount(detail.comments.length)),
                          ],
                        ),
                        if (_isOwner &&
                            currentBabyId != null &&
                            _memberBabies.any((b) => b.id != currentBabyId)) ...[
                          const SizedBox(height: 16),
                          Text(
                            'IN THIS PHOTO',
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
                                  FilterChip(
                                    label: Text(b.name),
                                    selected: _taggedBabyIds.contains(b.id),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _taggedBabyIds.add(b.id);
                                        } else {
                                          _taggedBabyIds.remove(b.id);
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
                            style: styles.bodySmall?.copyWith(color: AppColors.muted),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'COMMENTS',
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () =>
                                              _editComment(detail.comments[i]),
                                        ),
                                      if (detail.comments[i].canDelete)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          onPressed: () =>
                                              _deleteComment(detail.comments[i]),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: AppSemantics.textField(
                      'gallery_photo_comment',
                      AppTextField(
                        kind: AppTextInputKind.prose,
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                  ),
                  AppSemantics.button(
                    'gallery_comment_send',
                    IconButton(
                      onPressed: _addComment,
                      icon: const Icon(Icons.send),
                    ),
                    label: 'Send comment',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
