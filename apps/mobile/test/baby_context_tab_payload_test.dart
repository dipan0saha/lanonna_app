import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/presentation/baby_context_reload.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tabDisplayedPayloadIsCurrent is false when selection moved to another baby', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'milo'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    store.selectBaby('milo');

    expect(
      tabDisplayedPayloadIsCurrent(
        store: store,
        displayedBabyId: 'luna',
        loadedBabyId: 'luna',
        loadedSelectionGeneration: 0,
      ),
      isFalse,
    );
  });

  test('tabDisplayedPayloadIsCurrent is false when selection generation advanced', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'luna'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    store.selectBaby('luna');
    final generation = store.selectionGeneration;
    store.selectBaby('milo');

    expect(
      tabDisplayedPayloadIsCurrent(
        store: store,
        displayedBabyId: 'luna',
        loadedBabyId: 'luna',
        loadedSelectionGeneration: generation,
      ),
      isFalse,
    );
  });

  test('tabDisplayedPayloadIsCurrent is true for matching baby and generation', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'luna'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    store.selectBaby('luna');
    final generation = store.selectionGeneration;

    expect(
      tabDisplayedPayloadIsCurrent(
        store: store,
        displayedBabyId: 'luna',
        loadedBabyId: 'luna',
        loadedSelectionGeneration: generation,
      ),
      isTrue,
    );
  });
}
