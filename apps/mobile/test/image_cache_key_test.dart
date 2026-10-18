import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/media/image_cache_key.dart';

String signed(String object, String sig) =>
    'https://storage.googleapis.com/lanonna-dev-display/$object'
    '?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Date=20261018T080000Z'
    '&X-Goog-Expires=900&X-Goog-SignedHeaders=host&X-Goog-Signature=$sig';

void main() {
  test('a signed URL is keyed by bucket and object, not its signature', () {
    final a = signed('display/1b2c.webp', 'aaa');
    final b = signed('display/1b2c.webp', 'bbb');
    expect(imageCacheKeyForUrl(a), imageCacheKeyForUrl(b));
    expect(
      imageCacheKeyForUrl(a),
      'storage.googleapis.com/lanonna-dev-display/display/1b2c.webp',
    );
  });

  test('different objects keep different keys', () {
    expect(
      imageCacheKeyForUrl(signed('thumbnails/1b2c.jpg', 'x')),
      isNot(imageCacheKeyForUrl(signed('display/1b2c.webp', 'x'))),
    );
    expect(
      imageCacheKeyForUrl(signed('avatars/users/u/1.jpg', 'x')),
      isNot(imageCacheKeyForUrl(signed('avatars/users/u/2.jpg', 'x'))),
    );
  });

  test('an unsigned URL is its own key (its query may matter)', () {
    const u = 'https://example.com/a.png?size=2';
    expect(imageCacheKeyForUrl(u), u);
    expect(
      imageCacheKeyForUrl('https://example.com/a.png'),
      'https://example.com/a.png',
    );
  });
}
