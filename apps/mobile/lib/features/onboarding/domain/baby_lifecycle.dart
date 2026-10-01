enum BabyLifecycle {
  expecting,
  born,
}

extension BabyLifecycleApi on BabyLifecycle {
  String get apiValue => name;
}
