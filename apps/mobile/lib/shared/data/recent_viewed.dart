import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

const _key = 'recent_viewed_v1';

class RecentViewedController extends StateNotifier<List<Property>> {
  RecentViewedController() : super(const []) {
    _load();
  }

  static const maxItems = 12;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Property.fromJson)
          .toList();
      state = list;
    } catch (_) {
      // تجاهل بيانات قديمة تالفة
    }
  }

  Future<void> record(Property property) async {
    if (state.isNotEmpty && state.first.id == property.id) return;
    state = [
      property,
      ...state.where((item) => item.id != property.id),
    ].take(maxItems).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((item) => item.toCacheJson()).toList()),
    );
  }
}

final recentViewedProvider =
    StateNotifierProvider<RecentViewedController, List<Property>>(
  (ref) => RecentViewedController(),
);
