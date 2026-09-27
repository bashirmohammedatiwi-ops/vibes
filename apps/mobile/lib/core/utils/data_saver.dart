import 'package:connectivity_plus/connectivity_plus.dart';

/// وضع توفير البيانات — صور بدقة أقل على الشبكات البطيئة
class DataSaver {
  DataSaver._();

  static bool _slow = false;
  static bool _ready = false;
  static bool forced = false;

  static bool get slow => forced || _slow;
  static bool get active => slow;

  static Future<void> warm() async {
    if (_ready) return;
    _slow = await isSlowNetwork;
    _ready = true;
  }

  static Future<bool> get isSlowNetwork async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }
}
