import 'dart:convert';

import 'package:flutter/services.dart';

class RegistrySuggestion {
  RegistrySuggestion({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

abstract final class RegistrySuggestionsCatalog {
  static Map<String, List<RegistrySuggestion>>? _cache;

  static String defaultTabForLifecycle(String? lifecycleStatus) {
    switch (lifecycleStatus) {
      case 'born':
      case 'newborn':
        return 'newborn';
      default:
        return 'expecting';
    }
  }

  static Future<List<RegistrySuggestion>> forTab(String key) async {
    _cache ??= await _load();
    return _cache![key] ?? [];
  }

  static Future<Map<String, List<RegistrySuggestion>>> _load() async {
    final raw = await rootBundle.loadString(
      'assets/registry/registry_suggestions.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<RegistrySuggestion>>{};
    for (final entry in decoded.entries) {
      out[entry.key] = (entry.value as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => RegistrySuggestion(
              id: m['id'] as String,
              name: m['name'] as String,
              description: m['description'] as String? ?? '',
            ),
          )
          .toList();
    }
    return out;
  }
}
