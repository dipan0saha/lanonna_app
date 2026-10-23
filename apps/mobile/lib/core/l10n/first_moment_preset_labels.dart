import '../../l10n/app_localizations.dart';

extension FirstMomentPresetLabels on AppLocalizations {
  String firstMomentEventLabel(String id) {
    switch (id) {
      case 'gender_reveal':
        return labelGenderReveal;
      case 'baby_shower':
        return labelBabyShower;
      case 'due_date':
        return presetDueDate;
      case 'first_pediatric_visit':
        return presetFirstPediatricVisit;
      case 'baptism':
        return presetBaptism;
      case 'first_holidays':
        return presetFirstHolidays;
      default:
        return id;
    }
  }

  String firstMomentRegistryLabel(String id) {
    switch (id) {
      case 'swaddle_blankets':
        return presetSwaddleBlankets;
      case 'crib_mattress':
        return presetCribMattress;
      case 'diaper_stockpile':
        return presetDiaperStockpile;
      case 'onesies':
        return presetOnesies;
      case 'bottles':
        return presetBottles;
      default:
        return id;
    }
  }
}
