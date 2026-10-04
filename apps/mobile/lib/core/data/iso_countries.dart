import 'dart:convert';

import 'package:flutter/services.dart';

class IsoCountry {
  const IsoCountry({required this.code, required this.name});

  final String code;
  final String name;

  factory IsoCountry.fromJson(Map<String, dynamic> json) {
    return IsoCountry(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class IsoCountries {
  IsoCountries._();

  static List<IsoCountry>? _cache;

  static Future<List<IsoCountry>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/iso3166_countries.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .whereType<Map<String, dynamic>>()
        .map(IsoCountry.fromJson)
        .toList();
    return _cache!;
  }
}
