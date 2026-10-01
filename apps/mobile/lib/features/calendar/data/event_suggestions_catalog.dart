import 'dart:convert';

import 'package:flutter/services.dart';

class EventSuggestion {
  EventSuggestion({required this.title, required this.description});

  final String title;
  final String description;
}

class EventSuggestionsCatalog {
  static Map<String, List<EventSuggestion>>? _cache;

  static Future<List<EventSuggestion>> forLifecycle(String lifecycleStatus) async {
    _cache ??= await _load();
    final key = _stageKey(lifecycleStatus);
    return _cache![key] ?? _cache!['expecting'] ?? [];
  }

  static String _stageKey(String lifecycle) {
    switch (lifecycle) {
      case 'born':
      case 'newborn':
        return 'newborn';
      default:
        return 'expecting';
    }
  }

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
              title: m['title'] as String,
              description: m['description'] as String? ?? '',
            ),
          )
          .toList();
    }
    return out;
  }
}
