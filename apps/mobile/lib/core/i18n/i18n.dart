import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// الترجمة: النص العربي في الكود هو المفتاح، وen.json يربطه بالإنجليزية.
/// العربية لا تحتاج ملفاً؛ وأي نص بلا ترجمة يظهر بالعربية بدل مفتاح مكسور.
abstract final class I18n {
  static String locale = 'ar';
  static Map<String, String> _en = const {};

  static bool get isEn => locale == 'en';

  /// اسم التطبيق: «أجواء» بالعربية و VIBES بالإنجليزية.
  static String get appName => isEn ? 'VIBES' : 'أجواء'; // i18n-ok

  /// تُستدعى قبل runApp: اللغة المحفوظة، وإلا لغة الجهاز (العربية افتراضياً).
  static Future<void> init(SharedPreferences prefs) async {
    final saved = prefs.getString('locale');
    final device = PlatformDispatcher.instance.locale.languageCode;
    locale = saved ?? (device == 'en' ? 'en' : 'ar');
    final raw = await rootBundle.loadString('assets/translations/en.json');
    _en = (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  static String t(String key) => isEn ? (_en[key] ?? key) : key;
}

extension VibesTr on String {
  /// النص باللغة الحالية: `'الحجوزات'.tr`
  String get tr => I18n.t(this).split('|').last;

  /// نص بمتغيرات مسماة: `'مرحباً {name}'.trArgs({'name': name})`
  String trArgs(Map<String, Object?> args) {
    var out = I18n.t(this).split('|').last;
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  /// نص بعدد: `'{n} أيام'.trN(days)`. في en.json تُكتب الصيغتان بفاصل:
  /// `"{n} day|{n} days"`، والأولى للواحد فقط.
  String trN(num n) {
    final forms = I18n.t(this).split('|');
    final form = forms.length > 1 && n != 1 ? forms[1] : forms[0];
    return form.replaceAll('{n}', '$n');
  }
}
