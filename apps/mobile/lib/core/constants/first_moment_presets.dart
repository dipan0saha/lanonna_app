/// One first-moment onboarding preset the owner can pick (an event or a
/// registry item). The app sends only [id]; the API's
/// `lanonna_api/first_moment_presets.py` owns the seeded title, the date
/// (offsets from the due or birth date, clamped for expecting babies) and the
/// catalog id. `services/api/tests/test_first_moment_preset_parity.py` keeps
/// these ids in step with the API.
class FirstMomentPreset {
  const FirstMomentPreset(this.id);

  final String id;
}

abstract final class FirstMomentPresets {
  static const List<FirstMomentPreset> expectingEvents = [
    FirstMomentPreset('gender_reveal'),
    FirstMomentPreset('baby_shower'),
    FirstMomentPreset('due_date'),
  ];

  static const List<FirstMomentPreset> expectingRegistry = [
    FirstMomentPreset('swaddle_blankets'),
    FirstMomentPreset('crib_mattress'),
    FirstMomentPreset('diaper_stockpile'),
  ];

  static const List<FirstMomentPreset> bornEvents = [
    FirstMomentPreset('first_pediatric_visit'),
    FirstMomentPreset('baptism'),
    FirstMomentPreset('first_holidays'),
  ];

  static const List<FirstMomentPreset> bornRegistry = [
    FirstMomentPreset('diaper_pail'),
    FirstMomentPreset('onesies'),
    FirstMomentPreset('bottle_sterilizer'),
  ];
}
