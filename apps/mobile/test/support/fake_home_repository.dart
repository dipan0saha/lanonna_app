import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';

/// Offline [HomeRepository] whose selected baby is fixed. Subclass to stub more methods.
class FakeHomeRepository extends HomeRepository {
  FakeHomeRepository(this.baby)
      : super(ApiClient(idTokenProvider: () async => null));

  final BabySummary baby;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async => baby;
}
