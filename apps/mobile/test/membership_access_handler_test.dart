import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/auth/membership_access_handler.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingHomeRepository extends HomeRepository {
  _TrackingHomeRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  int resolveCalls = 0;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    resolveCalls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handleMembershipEnded refreshes baby context', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final repo = _TrackingHomeRepository();
    final signal = HomeRefreshSignal();
    var notified = false;
    signal.addListener(() => notified = true);

    await handleMembershipEnded(
      homeRepository: repo,
      store: store,
      signal: signal,
      exception: ApiException(
        'membership_ended',
        statusCode: 403,
        detail: {'error': 'membership_ended'},
      ),
    );

    expect(repo.resolveCalls, 1);
    expect(notified, isTrue);
  });
}
