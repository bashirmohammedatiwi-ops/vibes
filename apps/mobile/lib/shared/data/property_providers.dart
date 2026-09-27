import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../models/models.dart';

/// ═══════════════════════════════════════════════════════════
/// مزوّدات البيانات — الأماكن والريلز والمفضلة والمراجعات
/// ═══════════════════════════════════════════════════════════

final bannersProvider = FutureProvider<List<Banner>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/banners');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(Banner.fromJson)
      .where((b) => b.imageUrl.isNotEmpty)
      .toList();
});

/// قائمة الأماكن العامة بفلاتر
Future<List<Property>> fetchProperties(
  ApiClient client, {
  String? type,
  String? cityId,
  String? province,
  bool? featured,
  bool? isNew,
  String? q,
  String? sort,
  int page = 1,
  int pageSize = 20,
}) async {
  final data = await client.get(
    '/api/properties',
    queryParameters: {
      if (type != null) 'type': type,
      if (cityId != null) 'cityId': cityId,
      if (province != null) 'province': province,
      if (featured == true) 'featured': 'true',
      if (isNew == true) 'isNew': 'true',
      if (q != null && q.isNotEmpty) 'q': q,
      if (sort != null) 'sort': sort,
      'page': page,
      'pageSize': pageSize,
    },
  );

  final list = data is List ? data : (data['items'] as List<dynamic>? ?? []);
  return list.whereType<Map<String, dynamic>>().map(Property.fromJson).toList();
}

final propertiesProvider = FutureProvider.family<List<Property>, String?>((
  ref,
  type,
) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  return fetchProperties(client, type: type, pageSize: 16);
});

final newPropertiesProvider = FutureProvider.family<List<Property>, String>((
  ref,
  type,
) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  return fetchProperties(
    client,
    type: type,
    isNew: true,
    sort: 'newest',
    pageSize: 12,
  );
});

final spotlightsProvider = FutureProvider<List<HomeSpotlight>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/spotlights');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(HomeSpotlight.fromJson)
      .where((item) => item.imageUrl.isNotEmpty && item.propertyId.isNotEmpty)
      .toList();
});

final featuredPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  return fetchProperties(client, featured: true, pageSize: 8);
});

final topRatedPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  return fetchProperties(client, sort: 'rating', pageSize: 8);
});

final propertyDetailProvider = FutureProvider.family<Property, String>((
  ref,
  id,
) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/properties/$id');
  return Property.fromJson(data as Map<String, dynamic>);
});

final similarPropertiesProvider =
    FutureProvider.family<List<Property>, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/properties/$id/similar');
  final list = data is List ? data : (data['items'] as List<dynamic>? ?? []);
  return list.whereType<Map<String, dynamic>>().map(Property.fromJson).toList();
});

/// التوفر + الأسعار اليومية لشهر معين
final availabilityProvider =
    FutureProvider.family<AvailabilityData, ({String id, String? month})>((
      ref,
      params,
    ) async {
      final client = ref.watch(apiClientProvider);
      final data =
          await client.get(
                '/api/properties/${params.id}/availability',
                queryParameters: {
                  if (params.month != null) 'month': params.month,
                },
              )
              as Map<String, dynamic>;

      final slots = (data['slots'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((s) => s['isAvailable'] == false)
          .map((s) => '${(s['date'] as String).substring(0, 10)}:${s['shift']}')
          .toSet();

      final dayPrices = (data['dayPrices'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DayPricing.fromJson)
          .toList();

      final rawMode = data['bookingMode'] as String?;
      final mode = switch (rawMode) {
        'FULL_DAY' => BookingMode.fullDay,
        'SHIFTS' => BookingMode.shifts,
        'HYBRID' => BookingMode.hybrid,
        _ => null,
      };

      return AvailabilityData(
        slots: slots,
        dayPrices: dayPrices,
        bookingMode: mode,
      );
    });

/// تغذية الريلز — فيديوهات عمودية بالأماكن
final reelsProvider = FutureProvider<List<ReelItem>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);

  List<dynamic> items;
  try {
    final data = await client.get('/api/reels') as Map<String, dynamic>;
    items = data['items'] as List<dynamic>? ?? [];
    final reels = items
        .whereType<Map<String, dynamic>>()
        .map(ReelItem.fromJson)
        .toList();
    if (reels.isNotEmpty) return reels;
  } catch (_) {
    // نحاول المسار الاحتياطي أدناه
  }

  // احتياط — نبنيها محلياً من الأماكن ذات الفيديو
  final properties = await fetchProperties(client, pageSize: 30);
  final reels = <ReelItem>[];
  for (final p in properties) {
    for (final m in p.media.where((m) => m.isVideo)) {
      reels.add(ReelItem(media: m, property: p));
    }
  }
  return reels;
});

/// ═════ المفضلة ═════

final favoritesProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<List<Property>>>((
      ref,
    ) {
      final controller = FavoritesController(ref);
      ref.listen<AuthState>(authControllerProvider, (prev, next) {
        if (prev?.loggedIn != next.loggedIn) controller.refresh();
      });
      return controller;
    });

class FavoritesController extends StateNotifier<AsyncValue<List<Property>>> {
  FavoritesController(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref ref;
  ApiClient get _client => ref.read(apiClientProvider);

  Future<void> _load() async {
    if (!ref.read(authControllerProvider).loggedIn) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final data = await _client.get('/api/favorites');
      state = AsyncValue.data(
        (data as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(Property.fromJson)
            .toList(),
      );
    } catch (e) {
      // جلسة منتهية أو زائر — لا نكسر الشاشات الأخرى
      state = const AsyncValue.data([]);
    }
  }

  Future<void> refresh() => _load();

  bool isFavorite(String id) =>
      state.valueOrNull?.any((p) => p.id == id) ?? false;

  Future<void> toggle(Property property) async {
    final current = state.valueOrNull ?? [];
    final exists = current.any((p) => p.id == property.id);

    // تحديث متفائل
    state = AsyncValue.data(
      exists
          ? current.where((p) => p.id != property.id).toList()
          : [...current, property],
    );

    try {
      if (exists) {
        await _client.delete('/api/favorites/${property.id}');
      } else {
        await _client.post('/api/favorites', body: {'propertyId': property.id});
      }
    } catch (_) {
      // تراجع عند الفشل
      state = AsyncValue.data(current);
    }
  }
}

/// تقييمات مكان
final propertyReviewsProvider = FutureProvider.family<List<Review>, String>((
  ref,
  id,
) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/properties/$id/reviews');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(Review.fromJson)
      .toList();
});

class CityOption {
  const CityOption({
    required this.id,
    required this.nameAr,
    required this.provinceName,
    this.provinceSlug,
  });

  final String id;
  final String nameAr;
  final String provinceName;
  final String? provinceSlug;

  String get label => '$nameAr · $provinceName';
}

final locationsProvider = FutureProvider<List<CityOption>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/provinces');
  final cities = <CityOption>[];
  for (final province
      in (data as List<dynamic>).whereType<Map<String, dynamic>>()) {
    final provinceName = '${province['nameAr'] ?? ''}';
    final provinceSlug = province['slug'] as String?;
    for (final city
        in (province['cities'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()) {
      cities.add(
        CityOption(
          id: '${city['id'] ?? ''}',
          nameAr: '${city['nameAr'] ?? ''}',
          provinceName: provinceName,
          provinceSlug: provinceSlug,
        ),
      );
    }
  }
  cities.sort((a, b) => a.label.compareTo(b.label));
  return cities;
});
