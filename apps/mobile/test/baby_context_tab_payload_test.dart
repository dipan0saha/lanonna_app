import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/presentation/baby_context_reload.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SelectedBabyStore> storeWith(String id) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': id});
    return SelectedBabyStore(await SharedPreferences.getInstance());
  }

  test('another baby\'s data is not current (#372)', () async {
    final store = await storeWith('milo');
    expect(
      tabDisplayedPayloadIsCurrent(store: store, displayedBabyId: 'luna'),
      isFalse,
    );
  });

  test('nothing displayed is not current', () async {
    final store = await storeWith('luna');
    expect(
      tabDisplayedPayloadIsCurrent(store: store, displayedBabyId: null),
      isFalse,
    );
  });

  test('the selected baby\'s data stays current after A -> B -> A', () async {
    final store = await storeWith('luna');
    await store.setSelectedBabyId('milo');
    await store.setSelectedBabyId('luna');
    expect(
      tabDisplayedPayloadIsCurrent(store: store, displayedBabyId: 'luna'),
      isTrue,
    );
  });
}
