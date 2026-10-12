import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StaffNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _callChannelId = 'staff_calls';
  static const _msgChannelId = 'staff_messages';
  static const _callNotifId = 9001;
  static const _msgNotifId = 9002;

  /// طلب إذن الإشعارات على iOS (يُستدعى بعد الدخول، لا عند الإقلاع).
  static Future<void> requestIosPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS: إعدادات Darwin إلزامية — بدونها يرمي initialize خطأً قبل runApp
    // فيعلق التطبيق على شاشة الشعار. الإذن يُطلب لاحقاً لا عند الإقلاع.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings);
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _callChannelId,
        'مكالمات المكتب',
        description: 'تنبيهات المكالمات الواردة للموظفين',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _msgChannelId,
        'رسائل المكتب',
        description: 'تنبيهات الرسائل الجديدة',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  static Future<void> showIncomingCall({
    required String callerName,
    String? place,
  }) async {
    final body = place != null && place.isNotEmpty
        ? '$callerName · $place'
        : callerName;
    await _plugin.show(
      _callNotifId,
      'مكالمة واردة',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannelId,
          'مكالمات المكتب',
          channelDescription: 'تنبيهات المكالمات الواردة',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  static Future<void> cancelIncomingCall() => _plugin.cancel(_callNotifId);

  static Future<void> showNewMessage({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _msgNotifId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _msgChannelId,
          'رسائل المكتب',
          channelDescription: 'تنبيهات الرسائل الجديدة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}
