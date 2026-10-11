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

/// كل الأماكن المنشورة — صفحات من 100 حتى نهاية القائمة (حد أقصى 10 صفحات).
/// كانت تُطلب أول 16 فقط، فتختفي الأماكن المضافة لاحقاً من القوائم والخريطة.
Future<List<Property>> fetchAllProperties(ApiClient client, {String? type}) async {
  const size = 100;
  final all = <Property>[];
  for (var page = 1; page <= 10; page++) {
    final batch = await fetchProperties(client, type: type, page: page, pageSize: size);
    all.addAll(batch);
    if (batch.length < size) break;
  }
  return all;
}

final propertiesProvider = FutureProvider.family<List<Property>, String?>((
  ref,
  type,
) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  return fetchAllProperties(client, type: type);
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

final similarPropertiesProvider = FutureProvider.family<List<Property>, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/api/properties/$id/similar');
    final list = data is List ? data : (data['items'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
        .toList();
  },
);

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

/// تغذية الريلز — فيديوهات عمودية بالأماكن، مع ترقيم صفحات لانهائي:
/// تجلب دفعة أولى، وتحمّل المزيد تلقائياً قرب النهاية (cursor-based).
class ReelsFeedController extends StateNotifier<AsyncValue<List<ReelItem>>> {
  ReelsFeedController(this._client) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final ApiClient _client;
  String? _nextCursor;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  List<ReelItem> _fallbackItems = const [];

  Future<void> loadInitial() async {
    _nextCursor = null;
    _reachedEnd = false;
    state = const AsyncValue.loading();
    try {
      final data = await _client.get('/api/reels') as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      final reels = items
          .whereType<Map<String, dynamic>>()
          .map(ReelItem.fromJson)
          .where((r) => r.media.kind == MediaKind.reel)
          .toList();
      _nextCursor = data['nextCursor'] as String?;
      _reachedEnd = _nextCursor == null;
      if (reels.isNotEmpty) {
        state = AsyncValue.data(reels);
        return;
      }
    } catch (_) {
      // نحاول المسار الاحتياطي أدناه
    }

    // احتياط — نبنيها محلياً من الأماكن ذات الفيديو
    try {
      final properties = await fetchAllProperties(_client);
      final reels = <ReelItem>[];
      for (final p in properties) {
        for (final m in p.media.where((m) => m.kind == MediaKind.reel)) {
          reels.add(ReelItem(media: m, property: p));
        }
      }
      _fallbackItems = reels;
      _reachedEnd = true;
      state = AsyncValue.data(reels);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// يُستدعى قرب نهاية القائمة — يجلب الدفعة التالية بصمت.
  Future<void> loadMore() async {
    if (_loadingMore || _reachedEnd) return;
    final current = state.valueOrNull;
    if (current == null) return;
    // في وضع الاحتياط لا يوجد cursor — لا مزيد
    if (_fallbackItems.isNotEmpty) {
      _reachedEnd = true;
      return;
    }
    _loadingMore = true;
    try {
      final data =
          await _client.get('/api/reels?cursor=$_nextCursor')
              as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      final more = items
          .whereType<Map<String, dynamic>>()
          .map(ReelItem.fromJson)
          .where((r) => r.media.kind == MediaKind.reel)
          .toList();
      _nextCursor = data['nextCursor'] as String?;
      _reachedEnd = _nextCursor == null || more.isEmpty;
      // dedupe بالوسيط id — لا تكرار عند تداخل الدفعات
      final seen = current.map((r) => r.media.id).toSet();
      state = AsyncValue.data([
        ...current,
        ...more.where((r) => seen.add(r.media.id)),
      ]);
    } catch (_) {
      // فشل صامت — المحاولة القادمة عند الاقتراب مجدداً
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() => loadInitial();
}

final reelsProvider =
    StateNotifierProvider<ReelsFeedController, AsyncValue<List<ReelItem>>>((
      ref,
    ) {
      final client = ref.watch(apiClientProvider);
      return ReelsFeedController(client);
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
    this.provinceImageUrl,
  });

  final String id;
  final String nameAr;
  final String provinceName;
  final String? provinceSlug;
  final String? provinceImageUrl;

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
    final rawImage = province['imageUrl'];
    final provinceImageUrl = rawImage is String && rawImage.isNotEmpty
        ? rawImage
        : null;
    for (final city
        in (province['cities'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()) {
      cities.add(
        CityOption(
          id: '${city['id'] ?? ''}',
          nameAr: '${city['nameAr'] ?? ''}',
          provinceName: provinceName,
          provinceSlug: provinceSlug,
          provinceImageUrl: provinceImageUrl,
        ),
      );
    }
  }
  cities.sort((a, b) => a.label.compareTo(b.label));
  return cities;
});
