/// ═══════════════════════════════════════════════════════════
/// VIBES — الموديلات المكتوبة الكاملة
/// تحويل دفاعي من JSON (يحتمل أنواعاً متعددة من الـ API)
/// ═══════════════════════════════════════════════════════════

num _num(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? fallback;
}

String _str(dynamic v, [String fallback = '']) =>
    v?.toString() ?? fallback;

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

// ── الوسائط ──

enum MediaKind { image, video, reel, panorama }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.url,
    this.kind = MediaKind.image,
    this.posterUrl,
    this.aspectRatio,
    this.durationSec,
    this.width,
    this.height,
    this.caption,
    this.isPrimary = false,
  });

  final String id;
  final String url;
  final MediaKind kind;
  final String? posterUrl;
  final String? aspectRatio;
  final int? durationSec;
  final int? width;
  final int? height;
  final String? caption;
  final bool isPrimary;

  factory MediaItem.fromJson(Map<String, dynamic> j) {
    final type = _str(j['type'], 'IMAGE');
    return MediaItem(
      id: _str(j['id']),
      url: _str(j['url']),
      kind: switch (type) {
        'VIDEO' => MediaKind.video,
        'REEL' => MediaKind.reel,
        'PANORAMA' => MediaKind.panorama,
        _ => MediaKind.image,
      },
      posterUrl: j['posterUrl'] as String?,
      aspectRatio: j['aspectRatio'] as String?,
      durationSec: j['durationSec'] != null ? _num(j['durationSec']).toInt() : null,
      width: j['width'] != null ? _num(j['width']).toInt() : null,
      height: j['height'] != null ? _num(j['height']).toInt() : null,
      caption: j['caption'] as String?,
      isPrimary: j['isPrimary'] == true,
    );
  }

  bool get isVideo => kind == MediaKind.video || kind == MediaKind.reel;
  bool get isVertical =>
      aspectRatio == '9:16' || (height != null && width != null && height! > width!);
}

// ── المزايا ──

class Amenity {
  const Amenity({
    required this.id,
    required this.nameAr,
    this.icon,
    this.category = 'general',
  });

  final String id;
  final String nameAr;
  final String? icon;
  final String category;

  factory Amenity.fromJson(Map<String, dynamic> j) => Amenity(
        id: _str(j['id']),
        nameAr: _str(j['nameAr']),
        icon: j['icon'] as String?,
        category: _str(j['category'], 'general'),
      );
}

// ── المكان ──

enum PropertyType { farm, hall, decoration }
enum BookingMode { fullDay, shifts, hybrid }

class Property {
  const Property({
    required this.id,
    required this.name,
    required this.type,
    this.slug,
    this.description = '',
    this.cityName,
    this.provinceName,
    this.address,
    this.latitude,
    this.longitude,
    this.capacity = 0,
    this.pricePerDay = 0,
    this.weekendPrice,
    this.priceMorningShift,
    this.priceEveningShift,
    this.bookingMode,
    this.morningStart,
    this.morningEnd,
    this.eveningStart,
    this.eveningEnd,
    this.phone,
    this.whatsapp,
    this.featured = false,
    this.status,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.viewCount = 0,
    this.media = const [],
    this.amenityNames = const [],
    this.amenities = const [],
    this.tags = const [],
    this.rules,
    this.reviews = const [],
    this.providerName,
    this.providerPhone,
    this.bookingsCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final PropertyType type;
  final String? slug;
  final String description;
  final String? cityName;
  final String? provinceName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int capacity;
  final num pricePerDay;
  final num? weekendPrice;
  final num? priceMorningShift;
  final num? priceEveningShift;
  final BookingMode? bookingMode;
  final String? morningStart;
  final String? morningEnd;
  final String? eveningStart;
  final String? eveningEnd;
  final String? phone;
  final String? whatsapp;
  final bool featured;
  final String? status;
  final num ratingAvg;
  final int ratingCount;
  final int viewCount;
  final List<MediaItem> media;
  final List<String> amenityNames;
  final List<Amenity> amenities;
  final List<String> tags;
  final String? rules;
  final List<Review> reviews;
  final String? providerName;
  final String? providerPhone;
  final int bookingsCount;
  final DateTime? createdAt;

  static PropertyType _type(String v) => switch (v) {
        'FARM' => PropertyType.farm,
        'HALL' => PropertyType.hall,
        'DECORATION' => PropertyType.decoration,
        _ => PropertyType.farm,
      };

  static BookingMode? _mode(String? v) => switch (v) {
        'FULL_DAY' => BookingMode.fullDay,
        'SHIFTS' => BookingMode.shifts,
        'HYBRID' => BookingMode.hybrid,
        _ => null,
      };

  factory Property.fromJson(Map<String, dynamic> j) {
    final city = j['city'] as Map<String, dynamic>?;
    final provider = j['provider'] as Map<String, dynamic>?;

    // amenityLinks العلائقية إن وُجدت، وإلا فالـ JSON القديم
    final links = (j['amenityLinks'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .map((l) => l['amenity'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(Amenity.fromJson)
        .toList();

    final legacyNames = (j['amenities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return Property(
      id: _str(j['id']),
      name: _str(j['name']),
      type: _type(_str(j['type'], 'FARM')),
      slug: j['slug'] as String?,
      description: _str(j['description']),
      cityName: city?['nameAr'] as String?,
      provinceName: city?['province'] is Map<String, dynamic>
          ? (city!['province'] as Map<String, dynamic>)['nameAr'] as String?
          : null,
      address: j['address'] as String?,
      latitude: j['latitude'] != null ? _num(j['latitude']).toDouble() : null,
      longitude: j['longitude'] != null ? _num(j['longitude']).toDouble() : null,
      capacity: _num(j['capacity']).toInt(),
      pricePerDay: _num(j['pricePerDay']),
      weekendPrice: j['weekendPrice'] != null ? _num(j['weekendPrice']) : null,
      priceMorningShift:
          j['priceMorningShift'] != null ? _num(j['priceMorningShift']) : null,
      priceEveningShift:
          j['priceEveningShift'] != null ? _num(j['priceEveningShift']) : null,
      bookingMode: _mode(j['bookingMode'] as String?),
      morningStart: j['morningStart'] as String?,
      morningEnd: j['morningEnd'] as String?,
      eveningStart: j['eveningStart'] as String?,
      eveningEnd: j['eveningEnd'] as String?,
      phone: j['phone'] as String?,
      whatsapp: j['whatsapp'] as String?,
      featured: j['featured'] == true,
      status: j['status'] as String?,
      ratingAvg: _num(j['ratingAvg']),
      ratingCount: _num(j['ratingCount']).toInt(),
      viewCount: _num(j['viewCount']).toInt(),
      media: (j['media'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MediaItem.fromJson)
              .toList() ??
          const [],
      amenityNames: legacyNames,
      amenities: links ?? const [],
      tags: (j['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rules: j['rules'] as String?,
      reviews: (j['reviews'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Review.fromJson)
              .toList() ??
          const [],
      providerName: provider?['businessName'] as String? ??
          (provider?['user'] is Map<String, dynamic>
              ? (provider!['user'] as Map<String, dynamic>)['name'] as String?
              : null),
      providerPhone: provider?['user'] is Map<String, dynamic>
          ? (provider!['user'] as Map<String, dynamic>)['phone'] as String?
          : null,
      bookingsCount:
          j['_count'] is Map<String, dynamic> && j['_count']['bookings'] != null
              ? _num(j['_count']['bookings']).toInt()
              : 0,
      createdAt: _date(j['createdAt']),
    );
  }

  /// أول صورة جاهزة — للبطاقات
  String? get coverUrl {
    for (final m in media) {
      if (m.kind == MediaKind.image && m.isPrimary) return m.url;
    }
    for (final m in media) {
      if (m.kind == MediaKind.image) return m.url;
    }
    for (final m in media) {
      return m.posterUrl ?? m.url;
    }
    return null;
  }

  MediaItem? get firstVideo {
    for (final m in media) {
      if (m.isVideo) return m;
    }
    return null;
  }

  bool get supportsShifts =>
      bookingMode == BookingMode.shifts || bookingMode == BookingMode.hybrid;

  /// أوقات الشفت المحلولة (افتراضات النظام عند غياب تخصيص المكان)
  ({String morning, String evening}) get shiftLabels => (
        morning: '${morningStart ?? '08:00'} – ${morningEnd ?? '14:00'}',
        evening: '${eveningStart ?? '16:00'} – ${eveningEnd ?? '22:00'}',
      );

  String get typeLabelAr => switch (type) {
        PropertyType.farm => 'مزرعة',
        PropertyType.hall => 'قاعة',
        PropertyType.decoration => 'تزيين',
      };
}

// ── الحجز ──

enum BookingStatus {
  pending,
  awaitingPayment,
  confirmed,
  cancelled,
  completed,
  disputed,
}

enum ShiftType { morning, evening, full }

class PaymentInfo {
  const PaymentInfo({
    required this.id,
    this.status = 'PENDING',
    this.method,
    this.amount = 0,
    this.proofUrl,
  });

  final String id;
  final String status;
  final String? method;
  final num amount;
  final String? proofUrl;

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        id: _str(j['id']),
        status: _str(j['status'], 'PENDING'),
        method: j['method'] as String?,
        amount: _num(j['amount']),
        proofUrl: j['proofUrl'] as String?,
      );

  bool get isPaid => status == 'PAID';
}

class Booking {
  const Booking({
    required this.id,
    required this.propertyId,
    this.propertyName,
    this.propertyType,
    this.cityName,
    this.userName,
    this.userPhone,
    required this.startDate,
    required this.endDate,
    this.shift = ShiftType.full,
    this.guests = 1,
    this.status = BookingStatus.pending,
    this.totalPrice = 0,
    this.discountAmount = 0,
    this.notes,
    this.payment,
    this.canReview = false,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String? propertyName;
  final String? propertyType;
  final String? cityName;
  final String? userName;
  final String? userPhone;
  final DateTime startDate;
  final DateTime endDate;
  final ShiftType shift;
  final int guests;
  final BookingStatus status;
  final num totalPrice;
  final num discountAmount;
  final String? notes;
  final PaymentInfo? payment;
  final bool canReview;
  final DateTime? createdAt;

  static BookingStatus _status(String v) => switch (v) {
        'PENDING' => BookingStatus.pending,
        'AWAITING_PAYMENT' => BookingStatus.awaitingPayment,
        'CONFIRMED' => BookingStatus.confirmed,
        'CANCELLED' => BookingStatus.cancelled,
        'COMPLETED' => BookingStatus.completed,
        'DISPUTED' => BookingStatus.disputed,
        _ => BookingStatus.pending,
      };

  static ShiftType _shift(String? v) => switch (v) {
        'MORNING' => ShiftType.morning,
        'EVENING' => ShiftType.evening,
        _ => ShiftType.full,
      };

  factory Booking.fromJson(Map<String, dynamic> j) {
    final property = j['property'] as Map<String, dynamic>?;
    return Booking(
      id: _str(j['id']),
      propertyId: _str(j['propertyId']),
      propertyName: property?['name'] as String?,
      propertyType: property?['type'] as String?,
      cityName: property?['city'] is Map<String, dynamic>
          ? (property!['city'] as Map<String, dynamic>)['nameAr'] as String?
          : null,
      userName: j['user'] is Map<String, dynamic>
          ? (j['user'] as Map<String, dynamic>)['name'] as String?
          : null,
      userPhone: j['user'] is Map<String, dynamic>
          ? (j['user'] as Map<String, dynamic>)['phone'] as String?
          : null,
      startDate: _date(j['startDate']) ?? DateTime.now(),
      endDate: _date(j['endDate']) ?? DateTime.now(),
      shift: _shift(j['shift'] as String?),
      guests: _num(j['guests'], 1).toInt(),
      status: _status(_str(j['status'], 'PENDING')),
      totalPrice: _num(j['totalPrice']),
      discountAmount: _num(j['discountAmount']),
      notes: j['notes'] as String?,
      payment: j['payment'] is Map<String, dynamic>
          ? PaymentInfo.fromJson(j['payment'] as Map<String, dynamic>)
          : null,
      createdAt: _date(j['createdAt']),
    );
  }

  String get statusLabelAr => switch (status) {
        BookingStatus.pending => 'بانتظار التأكيد',
        BookingStatus.awaitingPayment => 'بانتظار الدفع',
        BookingStatus.confirmed => 'مؤكد',
        BookingStatus.cancelled => 'ملغى',
        BookingStatus.completed => 'مكتمل',
        BookingStatus.disputed => 'نزاع',
      };

  String get shiftLabelAr => switch (shift) {
        ShiftType.morning => 'شفت صباحي',
        ShiftType.evening => 'شفت مسائي',
        ShiftType.full => 'يوم كامل',
      };

  int get nights =>
      endDate.difference(startDate).inDays.clamp(1, 365);
}

// ── التقييم ──

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment = '',
    this.userName,
    this.isVisible = true,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String? userName;
  final bool isVisible;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: _str(j['id']),
        rating: _num(j['rating']).toInt(),
        comment: _str(j['comment']),
        userName: j['user'] is Map<String, dynamic>
            ? (j['user'] as Map<String, dynamic>)['name'] as String?
            : null,
        isVisible: j['isVisible'] != false,
        createdAt: _date(j['createdAt']),
      );
}

// ── المستخدم ──

class User {
  const User({
    required this.id,
    required this.phone,
    this.name,
    this.role = 'CUSTOMER',
    this.avatar,
  });

  final String id;
  final String phone;
  final String? name;
  final String role;
  final String? avatar;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: _str(j['id']),
        phone: _str(j['phone']),
        name: j['name'] as String?,
        role: _str(j['role'], 'CUSTOMER'),
        avatar: j['avatar'] as String?,
      );

  bool get isProvider => role == 'PROVIDER';
  bool get isStaff => role == 'ADMIN' || role == 'STAFF';
}

// ── التوفر والأسعار اليومية ──

class DayPricing {
  const DayPricing({
    required this.date,
    required this.full,
    required this.morning,
    required this.evening,
    this.isBooked = false,
    this.isBlocked = false,
  });

  final DateTime date;
  final num full;
  final num morning;
  final num evening;
  final bool isBooked;
  final bool isBlocked;

  factory DayPricing.fromJson(Map<String, dynamic> j) {
    final prices = j['prices'] as Map<String, dynamic>? ?? {};
    return DayPricing(
      date: _date(j['date']) ?? DateTime.now(),
      full: _num(prices['full']),
      morning: _num(prices['morning']),
      evening: _num(prices['evening']),
      isBooked: j['isBooked'] == true,
      isBlocked: j['isBlocked'] == true,
    );
  }

  num priceFor(ShiftType shift) => switch (shift) {
        ShiftType.morning => morning,
        ShiftType.evening => evening,
        ShiftType.full => full,
      };

  bool get isPast => date.isBefore(DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ));
}

class AvailabilityData {
  const AvailabilityData({
    this.slots = const {},
    this.dayPrices = const [],
    this.bookingMode,
  });

  /// مفاتيح "yyyy-mm-dd:SHIFT" للأيام المغلقة
  final Set<String> slots;
  final List<DayPricing> dayPrices;
  final BookingMode? bookingMode;

  bool isBlocked(DateTime day, ShiftType shift) =>
      slots.contains(_key(day, shift));

  static String _key(DateTime d, ShiftType s) {
    final shift = switch (s) {
      ShiftType.morning => 'MORNING',
      ShiftType.evening => 'EVENING',
      ShiftType.full => 'FULL',
    };
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}:$shift';
  }

  DayPricing? pricingFor(DateTime day) {
    for (final p in dayPrices) {
      if (p.date.year == day.year &&
          p.date.month == day.month &&
          p.date.day == day.day) {
        return p;
      }
    }
    return null;
  }
}

// ── الإعدادات العامة ──

class AppSettings {
  const AppSettings({
    this.supportPhone,
    this.paymentInstructions = '',
    this.morningShiftStart = '08:00',
    this.morningShiftEnd = '14:00',
    this.eveningShiftStart = '16:00',
    this.eveningShiftEnd = '22:00',
    this.maintenanceMode = false,
  });

  final String? supportPhone;
  final String paymentInstructions;
  final String morningShiftStart;
  final String morningShiftEnd;
  final String eveningShiftStart;
  final String eveningShiftEnd;
  final bool maintenanceMode;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        supportPhone: j['supportPhone'] as String?,
        paymentInstructions: _str(j['paymentInstructions']),
        morningShiftStart: _str(j['morningShiftStart'], '08:00'),
        morningShiftEnd: _str(j['morningShiftEnd'], '14:00'),
        eveningShiftStart: _str(j['eveningShiftStart'], '16:00'),
        eveningShiftEnd: _str(j['eveningShiftEnd'], '22:00'),
        maintenanceMode: j['maintenanceMode'] == true,
      );
}

// ── الكوبون ──

class CouponPreview {
  const CouponPreview({
    required this.valid,
    this.code,
    this.discount = 0,
    this.totalAfterDiscount = 0,
    this.reason,
  });

  final bool valid;
  final String? code;
  final num discount;
  final num totalAfterDiscount;
  final String? reason;

  factory CouponPreview.fromJson(Map<String, dynamic> j) => CouponPreview(
        valid: j['valid'] == true,
        code: j['code'] as String?,
        discount: _num(j['discount']),
        totalAfterDiscount: _num(j['totalAfterDiscount']),
        reason: j['reason'] as String?,
      );
}

// ── الريلز ──

class ReelItem {
  const ReelItem({
    required this.media,
    required this.property,
  });

  final MediaItem media;
  final Property property;

  factory ReelItem.fromJson(Map<String, dynamic> j) => ReelItem(
        media: MediaItem.fromJson(j['media'] as Map<String, dynamic>),
        property: Property.fromJson(j['property'] as Map<String, dynamic>),
      );
}

// ── بانرات ──

class Banner {
  const Banner({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.imageUrl,
    this.linkUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? linkUrl;

  factory Banner.fromJson(Map<String, dynamic> j) => Banner(
        id: _str(j['id']),
        title: _str(j['title']),
        subtitle: _str(j['subtitle']),
        imageUrl: _str(j['imageUrl']),
        linkUrl: j['linkUrl'] as String?,
      );
}
