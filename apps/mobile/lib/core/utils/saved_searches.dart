import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedSearch {
  const SavedSearch({
    required this.query,
    this.type,
    this.province,
    this.cityId,
    this.capacity = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.sort,
  });

  final String query;
  final String? type;
  final String? province;
  final String? cityId;
  final int capacity;
  final num minPrice;
  final num maxPrice;
  final String? sort;

  bool get isEmpty =>
      query.trim().isEmpty &&
      type == null &&
      province == null &&
      cityId == null &&
      capacity == 0 &&
      minPrice == 0 &&
      maxPrice == 0 &&
      sort == null;

  String get signature => [
        query.trim(),
        type ?? '',
        province ?? '',
        cityId ?? '',
        '$capacity',
        '$minPrice',
        '$maxPrice',
        sort ?? '',
      ].join('|');

  String get label {
    const types = {
      'FARM': 'مزارع',
      'HALL': 'قاعات',
      'DECORATION': 'تزيين',
    };
    final parts = <String>[
      if (query.trim().isNotEmpty) query.trim(),
      ?types[type],
      ?province,
      if (capacity > 0) 'من $capacity ضيف',
    ];
    return parts.isEmpty ? 'بحث محفوظ' : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'query': query,
        'type': type,
        'province': province,
        'cityId': cityId,
        'capacity': capacity,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'sort': sort,
      };

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
        query: j['query'] as String? ?? '',
        type: j['type'] as String?,
        province: j['province'] as String?,
        cityId: j['cityId'] as String?,
        capacity: (j['capacity'] as num?)?.toInt() ?? 0,
        minPrice: j['minPrice'] as num? ?? 0,
        maxPrice: j['maxPrice'] as num? ?? 0,
        sort: j['sort'] as String?,
      );
}

class SavedSearchStore {
  static const _key = 'vibes_saved_searches';

  static Future<List<SavedSearch>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SavedSearch.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SavedSearch>> save(SavedSearch search) async {
    if (search.isEmpty) return load();
    final current = await load();
    final next = [
      search,
      ...current.where((item) => item.signature != search.signature),
    ].take(8).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }

  static Future<List<SavedSearch>> remove(String signature) async {
    final next =
        (await load()).where((item) => item.signature != signature).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }
}
