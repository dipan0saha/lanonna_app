import 'models/home_summary.dart';

sealed class HomeSummaryResult {
  const HomeSummaryResult();
}

final class HomeSummaryLoaded extends HomeSummaryResult {
  const HomeSummaryLoaded(this.summary);

  final HomeSummary summary;
}

final class HomeSummaryFailed extends HomeSummaryResult {
  const HomeSummaryFailed(this.error);

  final Object error;
}
