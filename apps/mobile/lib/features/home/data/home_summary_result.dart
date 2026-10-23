import 'models/home_summary.dart';

sealed class HomeSummaryResult {
  const HomeSummaryResult();
}

final class HomeSummaryLoaded extends HomeSummaryResult {
  const HomeSummaryLoaded(this.summary, {this.refreshError});

  final HomeSummary summary;

  /// Non-null when the request failed and [summary] is the cached copy. The
  /// caller decides whether the user asked for fresh data (pull-to-refresh,
  /// baby switch) and must hear about the failure (#421).
  final Object? refreshError;
}

final class HomeSummaryFailed extends HomeSummaryResult {
  const HomeSummaryFailed(this.error);

  final Object error;
}
