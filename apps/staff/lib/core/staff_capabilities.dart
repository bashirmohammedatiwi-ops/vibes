import 'session.dart';

/// تسميات الصلاحيات المعروضة للموظف.
const staffPermissionLabels = <String, String>{
  'calls.answer': 'الرد على المكالمات',
  'calls.outbound': 'اتصال صادر',
  'calls.monitor': 'مراقبة المشرف',
  'inbox.read': 'قراءة المحادثات',
  'inbox.reply': 'الرد في المحادثات',
  'inbox.assign': 'إسناد المحادثات',
  'inbox.note': 'ملاحظات داخلية',
  'bookings.read': 'عرض الحجوزات',
  'bookings.confirm': 'تأكيد الحجز',
  'bookings.cancel': 'إلغاء الحجز',
  'bookings.write': 'تعديل الحجز',
  'payments.verify': 'اعتماد الدفع',
  'payments.read': 'عرض المدفوعات',
  'refunds.review': 'مراجعة الاسترداد',
  'cancellations.review': 'مراجعة الإلغاء',
  'properties.read': 'عرض الأماكن',
  'properties.moderate': 'اعتماد الأماكن',
  'properties.write': 'إضافة وتعديل الأماكن',
  'providers.link': 'ربط المزودين',
  'providers.read': 'عرض المزودين',
  'users.read': 'ملف الزبائن',
  'content.moderate': 'محتوى التطبيق',
  'coupons.read': 'عرض الكوبونات',
  'coupons.write': 'تعديل الكوبونات',
  'invoices.read': 'عرض الفواتير',
  'reports.read': 'التقارير',
  'content.write': 'إضافة وتعديل البانرات والمميزة',
  'reviews.moderate': 'إدارة التقييمات والمنشورات',
  'locations.write': 'المحافظات والمدن',
  'amenities.write': 'المرافق والخدمات',
  'users.write': 'تعديل وإيقاف حسابات الزبائن',
  'payments.refund': 'استرداد المبالغ',
  'disputes.review': 'النزاعات',
  'settings.write': 'إعدادات المنصة',
  'activity.read': 'سجل النشاط والتنبيهات',
};

/// تسمية صلاحية — من كتالوج الخادم إن وُجد (يُحدَّث دون إصدار جديد)، وإلا المحلي.
String staffPermissionLabel(String code) {
  final catalog = Session.me['catalog'];
  if (catalog is Map && catalog['labels'] is Map) {
    final label = (catalog['labels'] as Map)[code];
    if (label != null) return label.toString();
  }
  return staffPermissionLabels[code] ?? code;
}

class OpsModule {
  const OpsModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.anyOf,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon; // material icon name key
  final List<String> anyOf;

  bool get visible => anyOf.any(Session.can);
}

/// وحدات لوحة العمليات — تظهر حسب صلاحيات الموظف فقط.
/// الأقسام الكبرى (section: true) تُعرض كبطاقات رئيسية، والباقي أدوات سريعة.
List<OpsModule> visibleOpsModules() {
  final everyone = staffPermissionLabels.keys.toList();
  final all = <OpsModule>[
    const OpsModule(
      id: 'desk',
      title: 'مكتب الحجوزات',
      subtitle: 'حجز جديد، تقويم، كل الحجوزات، العروض',
      icon: 'event',
      anyOf: ['bookings.read', 'bookings.write'],
    ),
    const OpsModule(
      id: 'people',
      title: 'الزبائن والمال',
      subtitle: 'زبائن، مزودون، مدفوعات، استرداد، نزاعات',
      icon: 'people',
      anyOf: [
        'users.read',
        'providers.read',
        'providers.link',
        'payments.read',
        'refunds.review',
        'disputes.review',
      ],
    ),
    const OpsModule(
      id: 'properties',
      title: 'الأماكن',
      subtitle: 'إضافة وتعديل، وسائط، أسعار، توفر، اعتماد',
      icon: 'home_work',
      anyOf: ['properties.read', 'properties.write'],
    ),
    const OpsModule(
      id: 'content',
      title: 'المحتوى والتسويق',
      subtitle: 'بانرات، مميزة، كوبونات، تقييمات، منشورات',
      icon: 'collections',
      anyOf: [
        'content.moderate',
        'content.write',
        'coupons.read',
        'coupons.write',
        'reviews.moderate',
      ],
    ),
    OpsModule(
      id: 'catalog',
      title: 'الإعدادات والتقارير',
      subtitle: 'محافظات، مرافق، إعدادات، تقارير، سجل النشاط',
      icon: 'tune',
      anyOf: everyone,
    ),
    const OpsModule(
      id: 'dashboard',
      title: 'لوحة اليوم',
      subtitle: 'أرقام لحظية',
      icon: 'dashboard',
      anyOf: ['reports.read', 'bookings.read', 'calls.answer'],
    ),
    const OpsModule(
      id: 'requests',
      title: 'الطلبات',
      subtitle: 'إلغاء واسترداد',
      icon: 'rule',
      anyOf: ['cancellations.review', 'refunds.review'],
    ),
    const OpsModule(
      id: 'invoices',
      title: 'الفواتير',
      subtitle: 'فواتير الحجوزات',
      icon: 'receipt',
      anyOf: ['invoices.read'],
    ),
  ];
  return all.where((m) => m.visible).toList();
}

/// الأقسام الكبرى في مركز العمليات.
const opsSectionIds = {'desk', 'people', 'properties', 'content', 'catalog'};

bool get hasOpsAccess => visibleOpsModules().isNotEmpty;
