import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// ═══════════════════════════════════════════════════════════
/// ترتيب وظهور أقسام الصفحة الرئيسية — من لوحة التحكم (`/api/home/layout`).
/// الافتراضي: كل الأقسام ظاهرة بالترتيب الأصلي (يعمل حتى لو تعذّر الاتصال).
/// ═══════════════════════════════════════════════════════════

class HomeLayout {
  const HomeLayout({
    required this.header,
    required this.body,
    required this.quickLinks,
  });

  /// مفاتيح أقسام الرأس الظاهرة بالترتيب.
  final List<String> header;

  /// مفاتيح أقسام المحتوى الظاهرة بالترتيب.
  final List<String> body;

  final Map<String, bool> quickLinks;

  static const defaultHeader = [
    'banners',
    'nearest',
    'quickLinks',
    'destinations',
  ];
  static const defaultBody = [
    'continueBooking',
    'editorsPicks',
    'occasions',
    'newArrivals',
    'winterFarms',
    'coupon',
    'topRated',
    'spotlights',
    'map',
    'recentlyViewed',
    'following',
    'trust',
    'allPlaces',
    'footer',
  ];

  static const defaults = HomeLayout(
    header: defaultHeader,
    body: defaultBody,
    quickLinks: {},
  );

  bool shows(String key) => body.contains(key) || header.contains(key);
  bool link(String key) => quickLinks[key] != false;

  static List<String> _list(Object? raw, List<String> catalog) {
    if (raw is! List) return catalog;
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final key = item['key'];
      if (key is! String || !catalog.contains(key) || !seen.add(key)) continue;
      if (item['enabled'] != false) out.add(key);
    }
    // أقسام جديدة في التطبيق لم تُضبط بعد في اللوحة → ظاهرة في آخرها
    for (final k in catalog) {
      if (!seen.contains(k)) out.add(k);
    }
    return out;
  }

  factory HomeLayout.fromJson(Map<String, dynamic> j) => HomeLayout(
    header: _list(j['header'], defaultHeader),
    body: _list(j['body'], defaultBody),
    quickLinks: {
      if (j['quickLinks'] is Map)
        for (final e in (j['quickLinks'] as Map).entries)
          '${e.key}': e.value != false,
    },
  );
}

final homeLayoutProvider = FutureProvider<HomeLayout>((ref) async {
  ref.keepAlive();
  try {
    final data = await ref
        .watch(apiClientProvider)
        .get('/api/home/layout')
        .timeout(const Duration(seconds: 6));
    return data is Map<String, dynamic>
        ? HomeLayout.fromJson(data)
        : HomeLayout.defaults;
  } catch (_) {
    return HomeLayout.defaults;
  }
});

/// التخطيط الحالي فوراً (الافتراضي حتى يصل الرد).
HomeLayout homeLayoutNow(WidgetRef ref) =>
    ref.watch(homeLayoutProvider).valueOrNull ?? HomeLayout.defaults;
