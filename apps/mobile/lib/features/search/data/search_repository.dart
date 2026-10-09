import '../../../core/api/api_client.dart';
import '../../../core/time/app_date_time.dart';

class SearchPhotoHit {
  SearchPhotoHit({required this.id, this.caption, this.thumbUrl});

  final String id;
  final String? caption;
  final String? thumbUrl;

  factory SearchPhotoHit.fromJson(Map<String, dynamic> json) => SearchPhotoHit(
        id: json['id'] as String,
        caption: json['caption'] as String?,
        thumbUrl: json['thumb_url'] as String?,
      );
}

class SearchEventHit {
  SearchEventHit({required this.id, required this.title, required this.startsAt});

  final String id;
  final String title;
  final DateTime startsAt;

  factory SearchEventHit.fromJson(Map<String, dynamic> json) => SearchEventHit(
        id: json['id'] as String,
        title: json['title'] as String,
        startsAt: parseApiInstant(json['starts_at'] as String),
      );
}

class SearchRegistryHit {
  SearchRegistryHit({required this.id, required this.name});

  final String id;
  final String name;

  factory SearchRegistryHit.fromJson(Map<String, dynamic> json) => SearchRegistryHit(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class SearchNameHit {
  SearchNameHit({required this.id, required this.name});

  final String id;
  final String name;

  factory SearchNameHit.fromJson(Map<String, dynamic> json) => SearchNameHit(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class SearchResults {
  SearchResults({
    required this.query,
    required this.photos,
    required this.events,
    required this.registryItems,
    required this.nameSuggestions,
  });

  final String query;
  final List<SearchPhotoHit> photos;
  final List<SearchEventHit> events;
  final List<SearchRegistryHit> registryItems;
  final List<SearchNameHit> nameSuggestions;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        query: json['query'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>? ?? [])
            .map((e) => SearchPhotoHit.fromJson(e as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) => SearchEventHit.fromJson(e as Map<String, dynamic>))
            .toList(),
        registryItems: (json['registry_items'] as List<dynamic>? ?? [])
            .map((e) => SearchRegistryHit.fromJson(e as Map<String, dynamic>))
            .toList(),
        nameSuggestions: (json['name_suggestions'] as List<dynamic>? ?? [])
            .map((e) => SearchNameHit.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty =>
      photos.isEmpty &&
      events.isEmpty &&
      registryItems.isEmpty &&
      nameSuggestions.isEmpty;
}

class SearchRepository {
  SearchRepository(this._api);

  final ApiClient _api;

  Future<SearchResults> search({
    required String babyId,
    required String query,
  }) async {
    final encoded = Uri.encodeQueryComponent(query);
    final json = await _api.getJson(
      '/v1/babies/$babyId/search?q=$encoded&limit=20',
    );
    return SearchResults.fromJson(json);
  }
}
