import '../../../core/comments/comment_thread_port.dart';
import 'calendar_repository.dart';

class EventCommentThread implements CommentThreadPort {
  EventCommentThread({
    required CalendarRepository repository,
    required String? Function() babyId,
    required String eventId,
  })  : _repository = repository,
        _babyId = babyId,
        _eventId = eventId;

  final CalendarRepository _repository;
  final String? Function() _babyId;
  final String _eventId;

  String _requireBabyId() {
    final babyId = _babyId();
    if (babyId == null || babyId.isEmpty) {
      throw StateError('No baby selected');
    }
    return babyId;
  }

  @override
  Future<void> add(String text) {
    return _repository.addComment(_requireBabyId(), _eventId, text);
  }

  @override
  Future<void> update(String commentId, String text) {
    return _repository.updateComment(
      _requireBabyId(),
      _eventId,
      commentId,
      text,
    );
  }

  @override
  Future<void> delete(String commentId) {
    return _repository.deleteComment(_requireBabyId(), _eventId, commentId);
  }
}
