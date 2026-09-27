import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';

/// ═══════════════════════════════════════════════════════════
/// بيانات بوابة المزوّد — كلها عبر /api/provider/* المحصور بملكيته
/// ═══════════════════════════════════════════════════════════

class ProviderCoverage {
  const ProviderCoverage({
    this.days = 30,
    this.propertyCount = 0,
    this.totalSlots = 0,
    this.platformDays = 0,
    this.externalDays = 0,
    this.closedDays = 0,
    this.openDays = 0,
  });

  final int days;
  final int propertyCount;
  final int totalSlots;
  final int platformDays;
  final int externalDays;
  final int closedDays;
  final int openDays;

  factory ProviderCoverage.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ProviderCoverage();
    return ProviderCoverage(
      days: (j['days'] as num?)?.toInt() ?? 30,
      propertyCount: (j['propertyCount'] as num?)?.toInt() ?? 0,
      totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
      platformDays: (j['platformDays'] as num?)?.toInt() ?? 0,
      externalDays: (j['externalDays'] as num?)?.toInt() ?? 0,
      closedDays: (j['closedDays'] as num?)?.toInt() ?? 0,
      openDays: (j['openDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProviderOverview {
  const ProviderOverview({
    this.propertyCount = 0,
    this.activeBookings = 0,
    this.pendingBookings = 0,
    this.monthRevenue = 0,
    this.monthBookings = 0,
    this.upcoming = const [],
    this.followersCount = 0,
    this.pendingOffers = 0,
    this.coverage = const ProviderCoverage(),
  });

  final int propertyCount;
  final int activeBookings;
  final int pendingBookings;
  final num monthRevenue;
  final int monthBookings;
  final List<Booking> upcoming;
  final int followersCount;
  final int pendingOffers;
  final ProviderCoverage coverage;

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
        followersCount: (j['followersCount'] as num?)?.toInt() ?? 0,
        pendingOffers: (j['pendingOffers'] as num?)?.toInt() ?? 0,
        coverage: ProviderCoverage.fromJson(
          j['coverage'] is Map<String, dynamic>
              ? j['coverage'] as Map<String, dynamic>
              : null,
        ),
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

class ProviderBookingsQuery {
  const ProviderBookingsQuery({this.status, this.origin});
  final String? status;
  final String? origin;

  @override
  bool operator ==(Object other) =>
      other is ProviderBookingsQuery &&
      status == other.status &&
      origin == other.origin;

  @override
  int get hashCode => Object.hash(status, origin);
}

final providerBookingsProvider =
    FutureProvider.family<ProviderBookingsPage, ProviderBookingsQuery>(
  (ref, query) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/api/provider/bookings',
      queryParameters: {
        'pageSize': 40,
        if (query.status != null && query.status!.isNotEmpty) 'status': query.status,
        if (query.origin != null && query.origin!.isNotEmpty) 'origin': query.origin,
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

Future<void> createExternalBooking(
  ApiClient client, {
  required String propertyId,
  required String startDate,
  String? endDate,
  String? shift,
  String? guestName,
  String? guestPhone,
  int? guests,
  num? totalPrice,
  String? notes,
}) async {
  await client.post(
    '/api/provider/external-bookings',
    body: {
      'propertyId': propertyId,
      'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (shift != null) 'shift': shift,
      if (guestName != null && guestName.isNotEmpty) 'guestName': guestName,
      if (guestPhone != null && guestPhone.isNotEmpty) 'guestPhone': guestPhone,
      if (guests != null) 'guests': guests,
      if (totalPrice != null) 'totalPrice': totalPrice,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );
}

Future<void> cancelExternalBooking(ApiClient client, String bookingId) async {
  await client.patch('/api/provider/bookings/$bookingId/cancel');
}
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
