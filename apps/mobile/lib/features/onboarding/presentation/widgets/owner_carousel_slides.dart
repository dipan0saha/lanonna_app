/// Owner carousel slide copy (EN; aligned with nonna ARB).
const int ownerCarouselSlideCount = 4;

(String title, String body) ownerCarouselSlide(int index) {
  switch (index) {
    case 0:
      return (
        "Your baby's story, in one private place",
        'Photos, updates, and everything in between, visible only to the people you invite.',
      );
    case 1:
      return (
        'Everyone gets to feel close',
        'Grandparents, aunts, uncles, and friends can follow along, no matter how far away they live.',
      );
    case 2:
      return (
        'Celebrate every milestone together',
        'Calendar events, a shared registry, and fun ways to mark the big days.',
      );
    case 3:
    default:
      return (
        'Never lose a moment',
        'Every photo and comment, saved in one safe place, for good.',
      );
  }
}
