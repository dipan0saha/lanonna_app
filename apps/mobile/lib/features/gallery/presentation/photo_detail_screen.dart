import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/media/cached_signed_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/gallery_repository.dart';
import '../data/models/photo_models.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({super.key, required this.photoId});

  final String photoId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoNavHint extends StatelessWidget {
  const _PhotoNavHint({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  BabySummary? _baby;
  PhotoDetail? _detail;
  List<String> _photoIds = [];
  var _loading = true;
  var _editingCaption = false;
  final _captionController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() => _loading = false);
        return;
      }
      final galleryRepo = context.read<GalleryRepository>();
      final photos = await galleryRepo.listPhotos(baby.id);
      final detail = await galleryRepo.fetchPhoto(baby.id, widget.photoId);
      _captionController.text = detail.caption ?? '';
      setState(() {
        _baby = baby;
        _detail = detail;
        _photoIds = photos.map((p) => p.id).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load photo: $e')),
        );
      }
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _saveCaption() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    await context.read<GalleryRepository>().updateCaption(
      baby.id,
      detail.id,
      _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
    );
    setState(() => _editingCaption = false);
    await _load();
  }

  Future<void> _toggleSquish() async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    await context.read<GalleryRepository>().toggleSquish(baby.id, detail.id);
    await _load();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null) return;
    await context.read<GalleryRepository>().addComment(
      baby.id,
      detail.id,
      text,
    );
    _commentController.clear();
    await _load();
  }

  Future<void> _deleteComment(PhotoComment comment) async {
    final baby = _baby;
    final detail = _detail;
    if (baby == null || detail == null || !comment.isMine) return;
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
    await context.read<GalleryRepository>().deleteComment(
      baby.id,
      detail.id,
      comment.id,
    );
    await _load();
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
          'This removes it for everyone who can see it — this can\'t be undone.',
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
    await context.read<GalleryRepository>().deletePhoto(baby.id, detail.id);
    if (mounted) context.pop();
  }

  void _goAdjacent(int delta) {
    final idx = _photoIds.indexOf(widget.photoId);
    if (idx < 0) return;
    final next = idx + delta;
    if (next < 0 || next >= _photoIds.length) return;
    context.replace('/gallery/photo/${_photoIds[next]}');
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    if (_loading) {
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
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
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
                          )
                        else
                          ColoredBox(
                            color: Colors.grey.shade300,
                            child: const Center(child: Text('Processing…')),
                          ),
                        if (_photoIds.length > 1) ...[
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _PhotoNavHint(
                                icon: Icons.keyboard_arrow_up,
                                onTap: () => _goAdjacent(-1),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _PhotoNavHint(
                                icon: Icons.keyboard_arrow_down,
                                onTap: () => _goAdjacent(1),
                              ),
                            ),
                          ),
                        ],
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
                                child: TextField(
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
                            OutlinedButton.icon(
                              onPressed: _toggleSquish,
                              icon: Icon(
                                detail.viewerHasSquished
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              label: Text('${detail.squishCount} squishes'),
                            ),
                            const SizedBox(width: 8),
                            Text('${detail.comments.length} comments'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'COMMENTS',
                          style: styles.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final c in detail.comments)
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
                                        c.authorDisplayName,
                                        style: styles.labelMedium,
                                      ),
                                      Text(c.body, style: styles.bodyMedium),
                                    ],
                                  ),
                                ),
                                if (c.isMine)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => _deleteComment(c),
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
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send),
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
