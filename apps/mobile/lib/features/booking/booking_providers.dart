import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';

/// حجوزات المستخدم الحالي
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/bookings');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(Booking.fromJson)
      .toList();
});

/// تفاصيل حجز واحد
final bookingDetailProvider =
    FutureProvider.family<Booking, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/bookings/$id');
  return Booking.fromJson(data as Map<String, dynamic>);
});
