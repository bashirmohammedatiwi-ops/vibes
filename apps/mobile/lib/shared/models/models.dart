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
      posterUrl: j['posterUrl'] as String? ?? j['thumbnailUrl'] as String?,
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
    this.isNew = false,
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
    this.providerId,
    this.followersCount = 0,
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
  final bool isNew;
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
  final String? providerId;
  final int followersCount;
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
      isNew: j['isNew'] == true,
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
      providerId: provider?['id'] as String? ?? j['providerId'] as String?,
      followersCount: provider?['_count'] is Map<String, dynamic>
          ? _num((provider!['_count'] as Map<String, dynamic>)['followers']).toInt()
          : 0,
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
      if (m.kind == MediaKind.image && m.isPrimary) {
        return m.posterUrl ?? m.url;
      }
    }
    for (final m in media) {
      if (m.kind == MediaKind.image) return m.posterUrl ?? m.url;
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

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'type': switch (type) {
          PropertyType.farm => 'FARM',
          PropertyType.hall => 'HALL',
          PropertyType.decoration => 'DECORATION',
        },
        'description': description,
        'pricePerDay': pricePerDay,
        'capacity': capacity,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'city': {
          'nameAr': cityName,
          'province': {'nameAr': provinceName},
        },
        if (coverUrl != null)
          'media': [
            {
              'id': 'cover',
              'url': coverUrl,
              'type': 'IMAGE',
              'isPrimary': true,
            },
          ],
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
    this.coverUrl,
    this.createdAt,
    this.conversationId,
    this.invoiceNumber,
    this.cancellationStatus,
    this.origin = 'PLATFORM',
    this.guestName,
    this.guestPhone,
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
  final String? coverUrl;
  final DateTime? createdAt;
  final String? conversationId;
  final String? invoiceNumber;
  final String? cancellationStatus;
  final String origin;
  final String? guestName;
  final String? guestPhone;

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
      userName: () {
        if (j['user'] is Map<String, dynamic>) {
          final name = (j['user'] as Map<String, dynamic>)['name'] as String?;
          if (name != null && name.trim().isNotEmpty) return name;
        }
        return j['guestName'] as String?;
      }(),
      userPhone: () {
        if (j['user'] is Map<String, dynamic>) {
          final phone = (j['user'] as Map<String, dynamic>)['phone'] as String?;
          if (phone != null && phone.trim().isNotEmpty) return phone;
        }
        return j['guestPhone'] as String?;
      }(),
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
      canReview: j.containsKey('canReview')
          ? j['canReview'] == true
          : _status(_str(j['status'], 'PENDING')) == BookingStatus.completed,
      coverUrl: () {
        final media = property?['media'];
        if (media is List && media.isNotEmpty && media.first is Map) {
          final first = media.first as Map<String, dynamic>;
          return (first['posterUrl'] ?? first['url']) as String?;
        }
        return property?['coverUrl'] as String?;
      }(),
      createdAt: _date(j['createdAt']),
      conversationId: j['conversation'] is Map<String, dynamic>
          ? _str((j['conversation'] as Map<String, dynamic>)['id'])
          : j['conversationId'] as String?,
      invoiceNumber: j['invoice'] is Map<String, dynamic>
          ? (j['invoice'] as Map<String, dynamic>)['number'] as String?
          : null,
      cancellationStatus: () {
        final requests = j['cancellationRequests'];
        if (requests is List &&
            requests.isNotEmpty &&
            requests.first is Map<String, dynamic>) {
          return (requests.first as Map<String, dynamic>)['status'] as String?;
        }
        return null;
      }(),
      origin: _str(j['origin'], 'PLATFORM'),
      guestName: j['guestName'] as String?,
      guestPhone: j['guestPhone'] as String?,
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

  bool get isExternal => origin == 'EXTERNAL';

  String get originLabelAr => isExternal ? 'خارجي' : 'تطبيق VIBEES';

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
    this.kycStatus,
  });

  final String id;
  final String phone;
  final String? name;
  final String role;
  final String? avatar;
  final String? kycStatus;

  factory User.fromJson(Map<String, dynamic> j) {
    final provider = j['provider'] is Map<String, dynamic>
        ? j['provider'] as Map<String, dynamic>
        : null;
    return User(
      id: _str(j['id']),
      phone: _str(j['phone']),
      name: j['name'] as String?,
      role: _str(j['role'], 'CUSTOMER'),
      avatar: j['avatar'] as String?,
      kycStatus: provider?['kycStatus'] as String? ?? j['kycStatus'] as String?,
    );
  }

  bool get isProvider => role == 'PROVIDER';
  bool get isStaff => role == 'ADMIN' || role == 'STAFF';

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'avatar': avatar,
        'kycStatus': kycStatus,
      };
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

class HomeSpotlight {
  const HomeSpotlight({
    required this.id,
    this.title = '',
    required this.imageUrl,
    required this.propertyId,
    this.propertyName = '',
    this.height = 176,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String propertyId;
  final String propertyName;
  final int height;

  factory HomeSpotlight.fromJson(Map<String, dynamic> j) {
    final property = j['property'] as Map<String, dynamic>?;
    return HomeSpotlight(
      id: _str(j['id']),
      title: _str(j['title']),
      imageUrl: _str(j['imageUrl']),
      propertyId: _str(j['propertyId'], property?['id'] as String? ?? ''),
      propertyName: _str(property?['name']),
      height: _num(j['height']).round().clamp(140, 280).toInt(),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.linkUrl,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? linkUrl;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _str(j['id']),
        type: _str(j['type'], 'SYSTEM'),
        title: _str(j['title']),
        body: _str(j['body']),
        linkUrl: j['linkUrl'] as String?,
        isRead: j['isRead'] == true,
        createdAt: _date(j['createdAt']),
      );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    this.kind = 'BOOKING',
    this.title = '',
    this.lastMessage,
    this.unread = 0,
    this.updatedAt,
    this.bookingId,
    this.cityName,
    this.pricePerDay,
    this.stage,
  });

  final String id;
  final String kind;
  final String title;
  final String? lastMessage;
  final int unread;
  final DateTime? updatedAt;
  final String? bookingId;
  final String? cityName;
  final num? pricePerDay;
  final String? stage;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    final booking = j['booking'] as Map<String, dynamic>?;
    final property = j['property'] as Map<String, dynamic>?;
    final last = j['lastMessage'] as Map<String, dynamic>?;
    return ConversationSummary(
      id: _str(j['id']),
      kind: _str(j['kind'], 'BOOKING'),
      title: property is Map<String, dynamic>
          ? _str((property)['name'], 'محادثة')
          : booking?['property'] is Map<String, dynamic>
          ? _str((booking!['property'] as Map<String, dynamic>)['name'], 'محادثة حجز')
          : (j['kind'] == 'SUPPORT' ? 'دعم VIBEES' : 'محادثة'),
      lastMessage: last?['kind'] == 'IMAGE' && _str(last?['body']).isEmpty
          ? 'صورة'
          : last?['body'] as String?,
      unread: _num(j['unread']).toInt(),
      updatedAt: _date(j['updatedAt']),
      bookingId: booking?['id'] as String?,
      cityName: property?['city'] is Map<String, dynamic>
          ? (property!['city'] as Map<String, dynamic>)['nameAr'] as String?
          : null,
      pricePerDay: property?['pricePerDay'] != null ? _num(property!['pricePerDay']) : null,
      stage: booking != null
          ? 'حجز قائم'
          : property != null
          ? 'يسأل قبل الحجز'
          : null,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    this.body = '',
    this.kind = 'TEXT',
    this.imageUrl,
    this.senderId,
    this.senderName,
    this.createdAt,
  });

  final String id;
  final String body;
  final String kind;
  final String? imageUrl;
  final String? senderId;
  final String? senderName;
  final DateTime? createdAt;

  bool get isSystem => kind == 'SYSTEM';

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: _str(j['id']),
      body: _str(j['body']),
      kind: _str(j['kind'], 'TEXT'),
      imageUrl: j['imageUrl'] as String?,
      senderId: j['senderId'] as String? ?? sender?['id'] as String?,
      senderName: sender?['name'] as String? ?? sender?['phone'] as String?,
      createdAt: _date(j['createdAt']),
    );
  }
}

class PriceOfferItem {
  const PriceOfferItem({
    required this.id,
    required this.amount,
    this.status = 'PENDING',
    this.propertyName,
    this.message = '',
    this.startDate,
    this.endDate,
    this.bookingId,
  });

  final String id;
  final num amount;
  final String status;
  final String? propertyName;
  final String message;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? bookingId;

  factory PriceOfferItem.fromJson(Map<String, dynamic> j) => PriceOfferItem(
        id: _str(j['id']),
        amount: _num(j['amount']),
        status: _str(j['status'], 'PENDING'),
        propertyName: j['property'] is Map<String, dynamic>
            ? (j['property'] as Map<String, dynamic>)['name'] as String?
            : null,
        message: _str(j['message']),
        startDate: _date(j['startDate']),
        endDate: _date(j['endDate']),
        bookingId: j['bookingId'] as String? ??
            (j['booking'] is Map<String, dynamic>
                ? (j['booking'] as Map<String, dynamic>)['id'] as String?
                : null),
      );
}

class SocialExperience {
  const SocialExperience({
    required this.id,
    required this.caption,
    this.mediaUrls = const [],
    this.propertyName,
    this.propertyId,
    this.authorName,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.liked = false,
  });

  final String id;
  final String caption;
  final List<String> mediaUrls;
  final String? propertyName;
  final String? propertyId;
  final String? authorName;
  final int likesCount;
  final int commentsCount;
  final bool liked;

  factory SocialExperience.fromJson(Map<String, dynamic> j) => SocialExperience(
        id: _str(j['id']),
        caption: _str(j['caption']),
        mediaUrls: (j['mediaUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        propertyName: j['property'] is Map<String, dynamic>
            ? (j['property'] as Map<String, dynamic>)['name'] as String?
            : null,
        propertyId: j['property'] is Map<String, dynamic>
            ? (j['property'] as Map<String, dynamic>)['id'] as String?
            : j['propertyId'] as String?,
        authorName: j['user'] is Map<String, dynamic>
            ? (j['user'] as Map<String, dynamic>)['name'] as String?
            : null,
        likesCount: _num(j['likesCount']).toInt(),
        commentsCount: _num(j['commentsCount']).toInt(),
        liked: j['liked'] == true,
      );
}

class SavedCollection {
  const SavedCollection({
    required this.id,
    required this.name,
    this.itemCount = 0,
    this.coverUrl,
    this.isDefault = false,
    this.ownerName,
  });

  final String id;
  final String name;
  final int itemCount;
  final String? coverUrl;
  final bool isDefault;
  final String? ownerName;

  factory SavedCollection.fromJson(Map<String, dynamic> j) => SavedCollection(
        id: _str(j['id']),
        name: _str(j['name']),
        itemCount: j['_count'] is Map<String, dynamic>
            ? _num((j['_count'] as Map<String, dynamic>)['items']).toInt()
            : (j['items'] is List ? (j['items'] as List).length : 0),
        coverUrl: j['coverUrl'] as String?,
        isDefault: j['isDefault'] == true,
        ownerName: j['user'] is Map<String, dynamic>
            ? (j['user'] as Map<String, dynamic>)['name'] as String?
            : null,
      );
}

class PublicCoupon {
  const PublicCoupon({
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.minBookingTotal,
    this.expiresAt,
    this.appliesToTypes = const [],
    this.propertyId,
    this.propertyName,
  });

  final String code;
  final String description;
  final String discountType;
  final num discountValue;
  final num? minBookingTotal;
  final DateTime? expiresAt;
  final List<String> appliesToTypes;
  final String? propertyId;
  final String? propertyName;

  String get discountLabel => discountType == 'PERCENT'
      ? '${discountValue.toInt()}%'
      : '${discountValue.toInt()} د.ع';

  bool matchesProperty({required String id, required String type}) {
    if (propertyId != null && propertyId != id) return false;
    if (appliesToTypes.isEmpty) return true;
    return appliesToTypes.contains(type);
  }

  factory PublicCoupon.fromJson(Map<String, dynamic> j) {
    final property = j['property'] is Map<String, dynamic>
        ? j['property'] as Map<String, dynamic>
        : null;
    return PublicCoupon(
      code: _str(j['code']),
      description: _str(j['description']),
      discountType: _str(j['discountType'], 'PERCENT'),
      discountValue: _num(j['discountValue']),
      minBookingTotal: j['minBookingTotal'] == null
          ? null
          : _num(j['minBookingTotal']),
      expiresAt: _date(j['expiresAt']),
      appliesToTypes: (j['appliesToTypes'] as List<dynamic>?)
              ?.map((v) => v.toString())
              .toList() ??
          const [],
      propertyId: property?['id'] as String?,
      propertyName: property?['name'] as String?,
    );
  }
}

class FollowedProvider {
  const FollowedProvider({
    required this.id,
    this.businessName,
    this.userName,
    this.avatar,
    this.verified = false,
    this.followers = 0,
    this.propertiesCount = 0,
  });

  final String id;
  final String? businessName;
  final String? userName;
  final String? avatar;
  final bool verified;
  final int followers;
  final int propertiesCount;

  String get displayName =>
      (businessName != null && businessName!.trim().isNotEmpty)
          ? businessName!.trim()
          : (userName ?? 'مزود');

  factory FollowedProvider.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map<String, dynamic>
        ? j['user'] as Map<String, dynamic>
        : null;
    return FollowedProvider(
      id: _str(j['id']),
      businessName: j['businessName'] as String?,
      userName: user?['name'] as String?,
      avatar: user?['avatar'] as String?,
      verified: j['verified'] == true,
      followers: _num(j['followers']).toInt(),
      propertiesCount: _num(j['propertiesCount']).toInt(),
    );
  }
}
