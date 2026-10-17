import 'package:lanonna/l10n/app_localizations.dart';

const int ownerCarouselSlideCount = 4;

(String title, String body) ownerCarouselSlide(AppLocalizations l10n, int index) {
  return switch (index) {
    0 => (l10n.ownerCarouselTitle1, l10n.ownerCarouselBody1),
    1 => (l10n.ownerCarouselTitle2, l10n.ownerCarouselBody2),
    2 => (l10n.ownerCarouselTitle3, l10n.ownerCarouselBody3),
    _ => (l10n.ownerCarouselTitle4, l10n.ownerCarouselBody4),
  };
}
