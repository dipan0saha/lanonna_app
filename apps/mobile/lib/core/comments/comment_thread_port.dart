/// Baby-scoped comment mutations shared by event detail and photo detail.
abstract interface class CommentThreadPort {
  Future<void> add(String text);
  Future<void> update(String commentId, String text);
  Future<void> delete(String commentId);
}
