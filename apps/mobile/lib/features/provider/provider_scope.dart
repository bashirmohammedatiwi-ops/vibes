import 'package:flutter_riverpod/flutter_riverpod.dart';

/// مكان محدّد مسبقاً عند فتح التقويم (من بطاقة الممتلك).
final providerCalendarPropertyIdProvider = StateProvider<String?>(
  (ref) => null,
);

/// فتح نموذج الحجز الخارجي تلقائياً بعد الانتقال للتقويم.
final providerCalendarOpenExternalProvider = StateProvider<bool>(
  (ref) => false,
);

/// فلتر الحالة الافتراضي لشاشة الحجوزات (مثلاً من تنبيه «بانتظارك»).
final providerBookingsStatusFilterProvider = StateProvider<String?>(
  (ref) => null,
);
