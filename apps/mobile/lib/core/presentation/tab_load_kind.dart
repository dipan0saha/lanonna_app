/// How a baby-scoped tab should render after a load attempt.
///
/// A failed load is never treated as "you have no baby". Cached payload stays
/// on screen; the empty state is only for a successful load that returned nothing.
enum TabLoadKind { loading, error, empty, content }

/// `loading` (nothing cached) → `error` → `empty` → `content`.
///
/// When [hasPayload] is true the last successful baby (and its content) stays
/// visible through a refresh, including a refresh that fails.
TabLoadKind resolveTabLoadKind({
  required bool loading,
  required bool hasError,
  required bool hasPayload,
}) {
  if (loading && !hasPayload) return TabLoadKind.loading;
  if (hasPayload) return TabLoadKind.content;
  if (hasError) return TabLoadKind.error;
  if (loading) return TabLoadKind.loading;
  return TabLoadKind.empty;
}
