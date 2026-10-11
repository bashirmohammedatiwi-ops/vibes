import 'package:permission_handler/permission_handler.dart';

class StaffPermissions {
  static Future<void> requestForCallCenter() async {
    await Permission.microphone.request();
    await Permission.notification.request();
  }

  static Future<bool> openBatterySettings() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    return await Permission.ignoreBatteryOptimizations.request().isGranted;
  }
}
