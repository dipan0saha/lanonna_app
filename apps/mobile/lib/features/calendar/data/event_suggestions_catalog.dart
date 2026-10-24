import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'dart:convert';

import 'package:flutter/services.dart';

class EventSuggestion {
  EventSuggestion({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

abstract final class EventSuggestionsCatalog {
  static Map<String, List<EventSuggestion>>? _cache;
  static Map<String, EventSuggestion>? _byId;

  static Future<List<EventSuggestion>> forTab(String key) async {
    _cache ??= await _load();
    return _cache![key] ?? [];
  }

  /// Canonical title for [id] from `event_suggestions.json` (catalog source of truth).
  static Future<String?> titleForId(String id) async {
    _byId ??= await _indexById();
    return _byId![id]?.title;
  }

  static Future<Map<String, EventSuggestion>> _indexById() async {
    _cache ??= await _load();
    return {
      for (final list in _cache!.values)
        for (final item in list)
          item.id: item,
    };
  }

  static String defaultTabForLifecycle(BabyLifecycle? lifecycle) =>
      lifecycle == BabyLifecycle.born ? 'newborn' : 'expecting';

  static Future<Map<String, List<EventSuggestion>>> _load() async {
    final raw = await rootBundle.loadString(
      'assets/calendar/event_suggestions.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<EventSuggestion>>{};
    for (final entry in decoded.entries) {
      final list = entry.value as List<dynamic>;
      out[entry.key] = list
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => EventSuggestion(
              id: m['id'] as String,
              title: m['title'] as String,
              description: m['description'] as String? ?? '',
            ),
          )
          .toList();
    }
    return out;
  }
}
