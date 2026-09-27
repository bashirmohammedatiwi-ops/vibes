import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'device_diagnostic_id';

Future<String> diagnosticDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_key);
  if (existing != null && existing.isNotEmpty) return existing;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final noise = Random().nextInt(9999).toString().padLeft(4, '0');
  final id = 'VIBES-$stamp-$noise';
  await prefs.setString(_key, id);
  return id;
}
