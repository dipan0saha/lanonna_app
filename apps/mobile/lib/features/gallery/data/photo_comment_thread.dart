import '../../../core/comments/comment_thread_port.dart';
import 'gallery_repository.dart';

class PhotoCommentThread implements CommentThreadPort {
  PhotoCommentThread({
    required GalleryRepository repository,
    required String? Function() babyId,
    required String Function() photoId,
  })  : _repository = repository,
        _babyId = babyId,
        _photoId = photoId;

  final GalleryRepository _repository;
  final String? Function() _babyId;
  final String Function() _photoId;

  String _requireBabyId() {
    final babyId = _babyId();
    if (babyId == null || babyId.isEmpty) {
      throw StateError('No baby selected');
    }
    return babyId;
  }

  @override
  Future<void> add(String text) {
    return _repository.addComment(_requireBabyId(), _photoId(), text);
  }

  @override
  Future<void> update(String commentId, String text) {
    return _repository.updateComment(
      _requireBabyId(),
      _photoId(),
      commentId,
      text,
    );
  }

  @override
  Future<void> delete(String commentId) {
    return _repository.deleteComment(_requireBabyId(), _photoId(), commentId);
  }
}
