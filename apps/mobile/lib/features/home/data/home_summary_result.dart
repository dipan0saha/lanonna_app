import 'models/home_summary.dart';

sealed class HomeSummaryResult {
  const HomeSummaryResult();
}

final class HomeSummaryLoaded extends HomeSummaryResult {
  const HomeSummaryLoaded(this.summary, {this.staleRefreshError});

  final HomeSummary summary;

  /// Non-null when [summary] is served from cache after a failed explicit
  /// refresh (pull-to-refresh, baby switch). UI should snackbar and keep
  /// showing [summary].
  final Object? staleRefreshError;
}

final class HomeSummaryFailed extends HomeSummaryResult {
  const HomeSummaryFailed(this.error);

  final Object error;
}
