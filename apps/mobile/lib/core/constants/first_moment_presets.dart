class FirstMomentEventPreset {
  const FirstMomentEventPreset({
    required this.id,
    required this.dayOffset,
  });

  final String id;
  final int dayOffset;
}

class FirstMomentRegistryPreset {
  const FirstMomentRegistryPreset({
    required this.id,
  });

  final String id;
}

abstract final class FirstMomentPresets {
  static const List<FirstMomentEventPreset> expectingEvents = [
    FirstMomentEventPreset(id: 'gender_reveal', dayOffset: -14),
    FirstMomentEventPreset(id: 'baby_shower', dayOffset: -7),
    FirstMomentEventPreset(id: 'due_date', dayOffset: 0),
  ];

  static const List<FirstMomentRegistryPreset> expectingRegistry = [
    FirstMomentRegistryPreset(id: 'swaddles'),
    FirstMomentRegistryPreset(id: 'crib'),
    FirstMomentRegistryPreset(id: 'diapers'),
  ];

  static const List<FirstMomentEventPreset> bornEvents = [
    FirstMomentEventPreset(id: 'first_checkup', dayOffset: 0),
    FirstMomentEventPreset(id: 'baptism', dayOffset: 7),
    FirstMomentEventPreset(id: 'first_holidays', dayOffset: 14),
  ];

  static const List<FirstMomentRegistryPreset> bornRegistry = [
    FirstMomentRegistryPreset(id: 'diapers'),
    FirstMomentRegistryPreset(id: 'onesies'),
    FirstMomentRegistryPreset(id: 'bottles'),
  ];
}
