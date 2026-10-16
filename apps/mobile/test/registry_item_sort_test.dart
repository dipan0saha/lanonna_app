import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/domain/registry_item_sort.dart';

RegistryItem _item(String name, int priority) {
  return RegistryItem(
    id: name,
    name: name,
    priority: priority,
    isPurchased: false,
  );
}

void main() {
  test('sortRegistryItems orders high priority first by default', () {
    final sorted = sortRegistryItems(
      [_item('low', 1), _item('high', 5), _item('mid', 3)],
      RegistryItemSort.priorityHighFirst,
    );
    expect(sorted.map((i) => i.name), ['high', 'mid', 'low']);
  });

  test('sortRegistryItems low first reverses priority', () {
    final sorted = sortRegistryItems(
      [_item('low', 1), _item('high', 5)],
      RegistryItemSort.priorityLowFirst,
    );
    expect(sorted.map((i) => i.name), ['low', 'high']);
  });

  test('sortRegistryItems breaks ties by name', () {
    final sorted = sortRegistryItems(
      [_item('b', 3), _item('a', 3)],
      RegistryItemSort.priorityHighFirst,
    );
    expect(sorted.map((i) => i.name), ['a', 'b']);
  });

  test('RegistryItemSort toggles between modes', () {
    expect(
      RegistryItemSort.priorityHighFirst.toggled,
      RegistryItemSort.priorityLowFirst,
    );
    expect(
      RegistryItemSort.priorityLowFirst.toggled,
      RegistryItemSort.priorityHighFirst,
    );
  });
}
