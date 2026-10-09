/// Shared loading UX for baby-scoped detail screens (photo, event, etc.).
bool shouldShowDetailFullScreenLoader({
  required bool hasContent,
  required bool initialLoadInFlight,
}) {
  return !hasContent && initialLoadInFlight;
}
