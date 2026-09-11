import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';

/// ═══════════════════════════════════════════════════════════
/// بيانات بوابة المزوّد — كلها عبر /api/provider/* المحصور بملكيته
/// ═══════════════════════════════════════════════════════════

class ProviderOverview {
  const ProviderOverview({
    this.propertyCount = 0,
    this.activeBookings = 0,
    this.pendingBookings = 0,
    this.monthRevenue = 0,
    this.monthBookings = 0,
    this.upcoming = const [],
  });

  final int propertyCount;
  final int activeBookings;
  final int pendingBookings;
  final num monthRevenue;
  final int monthBookings;
  final List<Booking> upcoming;

  factory ProviderOverview.fromJson(Map<String, dynamic> j) =>
      ProviderOverview(
        propertyCount: (j['propertyCount'] as num?)?.toInt() ?? 0,
        activeBookings: (j['activeBookings'] as num?)?.toInt() ?? 0,
        pendingBookings: (j['pendingBookings'] as num?)?.toInt() ?? 0,
        monthRevenue: j['monthRevenue'] is num
            ? j['monthRevenue'] as num
            : num.tryParse('${j['monthRevenue']}') ?? 0,
        monthBookings: (j['monthBookings'] as num?)?.toInt() ?? 0,
        upcoming: (j['upcoming'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList(),
      );
}

final providerOverviewProvider = FutureProvider<ProviderOverview>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/api/provider/overview');
    return ProviderOverview.fromJson(data as Map<String, dynamic>);
  },
);

final providerPropertiesProvider = FutureProvider<List<Property>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/api/provider/properties');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
        .toList();
  },
);

class ProviderBookingsPage {
  const ProviderBookingsPage({this.items = const [], this.total = 0});
  final List<Booking> items;
  final int total;
}

final providerBookingsProvider =
    FutureProvider.family<ProviderBookingsPage, String?>(
  (ref, status) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/api/provider/bookings',
      queryParameters: {
        'pageSize': 40,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ) as Map<String, dynamic>;

    return ProviderBookingsPage(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  },
);

/// الأرباح الشهرية
final providerRevenueProvider =
    FutureProvider.family<List<({String month, num revenue, int bookings})>, int>(
  (ref, months) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/api/provider/revenue',
      queryParameters: {'months': months},
    );
    return (data as List<dynamic>).whereType<Map<String, dynamic>>().map((row) {
      return (
        month: row['month'] as String,
        revenue: row['revenue'] is num
            ? row['revenue'] as num
            : num.tryParse('${row['revenue']}') ?? 0,
        bookings: (row['bookings'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  },
);

/// حجوزات ممتلكاتي لمكان واحد (للتقويم)
final providerPropertyBookingsProvider =
    FutureProvider.family<List<Booking>, String>((ref, propertyId) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get(
    '/api/provider/bookings',
    queryParameters: {'propertyId': propertyId, 'pageSize': 100},
  ) as Map<String, dynamic>;

  return (data['items'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(Booking.fromJson)
      .toList();
});

/// توفر مكان المزوّد (للحظر والفتح)
final providerAvailabilityProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({String id, String? month})>(
        (ref, p) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get(
    '/api/provider/properties/${p.id}/availability',
    queryParameters: {if (p.month != null) 'month': p.month},
  );
  return (data as List<dynamic>).whereType<Map<String, dynamic>>().toList();
});

/// معاينة أسعار المكان — سعر كل يوم كما يراه العميل
final providerPricingPreviewProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, propertyId) async {
    final client = ref.watch(apiClientProvider);
    final from = DateTime.now();
    final to = from.add(const Duration(days: 21));
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await client.get(
      '/api/provider/properties/$propertyId/pricing-preview',
      queryParameters: {'from': key(from), 'to': key(to)},
    ) as Map<String, dynamic>;
    return (data['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  },
);

/// إجراءات الحجز (تأكيد/إلغاء)
Future<void> updateBookingStatus(
  ApiClient client,
  String bookingId,
  String status,
) async {
  await client.patch(
    '/api/bookings/$bookingId/status',
    body: {'status': status},
  );
}

/// حظر/فتح أيام
Future<void> setAvailability(
  ApiClient client,
  String propertyId, {
  required List<String> dates,
  required bool available,
  String? shift,
}) async {
  await client.post(
    '/api/provider/properties/$propertyId/availability/bulk',
    body: {
      'dates': dates,
      'isAvailable': available,
      if (shift != null) 'shift': shift,
    },
  );
}
