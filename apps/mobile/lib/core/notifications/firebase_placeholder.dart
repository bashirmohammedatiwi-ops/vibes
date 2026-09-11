/// إشعارات الدفع — نقطة التفعيل الموحدة.
///
/// الآن: no-op آمن. عند تهيئة Firebase (google-services.json /
/// GoogleService-Info.plist + firebase_messaging في pubspec):
/// 1) استدعِ `init()` كما هو من main.
/// 2) داخل init استبدل جسم _registerDevice بـ getToken ثم POST /api/devices.
/// المسار الخلفي جاهز ويحفظ التوكنات لحساب المستخدم.
library;

Future<void> init() async {
  await _registerDevice();
}

Future<void> _registerDevice() async {
  // TODO(FCM): بعد إضافة firebase_messaging:
  // final token = await FirebaseMessaging.instance.getToken();
  // if (token == null) return;
  // await ApiClient(tokenStorage: ...).post('/api/devices',
  //   body: {'token': token, 'platform': defaultTargetPlatform.name});
  return;
}
