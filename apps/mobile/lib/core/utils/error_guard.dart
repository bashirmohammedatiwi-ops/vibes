import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس أخطاء عالمي — يلتقط أخطاء الإطار
/// ويحفظ آخر 20 محلياً لعرضها من الدعم الفني عند الحاجة.
class ErrorGuard {
  ErrorGuard._();

  static const _key = 'vibes_error_log';
  static final Queue<Map<String, String>> _log = ListQueue(20);

  static void init() {
    FlutterError.onError = (details) {
      _record(details.exceptionAsString(), details.library ?? 'framework');
      FlutterError.presentError(details);
    };
  }

  static void _record(String message, String zone) {
    _log.addLast({
      'at': DateTime.now().toIso8601String(),
      'zone': zone,
      'message': message.length > 300 ? message.substring(0, 300) : message,
    });
    _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lines = _log.map((e) => '${e['at']}|${e['zone']}|${e['message']}');
      await prefs.setStringList(_key, lines.toList());
    } catch (_) {
      // أفضل جهد
    }
  }

  /// لعرضها من صفحة الدعم
  static List<String> recent() => _log
      .map((e) => '${e['at']} — ${e['zone']}: ${e['message']}')
      .toList(growable: false);
}
