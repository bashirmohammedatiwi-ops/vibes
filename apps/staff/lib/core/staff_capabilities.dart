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
};

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
List<OpsModule> visibleOpsModules() {
  const all = <OpsModule>[
    OpsModule(
      id: 'dashboard',
      title: 'لوحة اليوم',
      subtitle: 'أرقام لحظية للعمل',
      icon: 'dashboard',
      anyOf: ['reports.read', 'bookings.read', 'calls.answer'],
    ),
    OpsModule(
      id: 'properties',
      title: 'الأماكن',
      subtitle: 'إضافة وتعديل ووسائط واعتماد',
      icon: 'home_work',
      anyOf: ['properties.read', 'properties.write'],
    ),
    OpsModule(
      id: 'bookings',
      title: 'الحجوزات',
      subtitle: 'تفاصيل وتأكيد وإلغاء',
      icon: 'event',
      anyOf: ['bookings.read'],
    ),
    OpsModule(
      id: 'payments',
      title: 'المدفوعات',
      subtitle: 'مراجعة الإثباتات',
      icon: 'payments',
      anyOf: ['payments.read', 'payments.verify'],
    ),
    OpsModule(
      id: 'providers',
      title: 'المزودون',
      subtitle: 'التحقق من الحسابات',
      icon: 'storefront',
      anyOf: ['providers.read', 'providers.link'],
    ),
    OpsModule(
      id: 'customers',
      title: 'الزبائن',
      subtitle: 'بحث بالهاتف أو الاسم',
      icon: 'people',
      anyOf: ['users.read'],
    ),
    OpsModule(
      id: 'requests',
      title: 'الطلبات',
      subtitle: 'إلغاء واسترداد',
      icon: 'rule',
      anyOf: ['cancellations.review', 'refunds.review'],
    ),
    OpsModule(
      id: 'content',
      title: 'المحتوى',
      subtitle: 'بانرات وتقييمات ومميزة',
      icon: 'collections',
      anyOf: ['content.moderate'],
    ),
    OpsModule(
      id: 'coupons',
      title: 'الكوبونات',
      subtitle: 'عرض وتفعيل الأكواد',
      icon: 'local_offer',
      anyOf: ['coupons.read', 'coupons.write'],
    ),
    OpsModule(
      id: 'invoices',
      title: 'الفواتير',
      subtitle: 'فواتير الحجوزات',
      icon: 'receipt',
      anyOf: ['invoices.read'],
    ),
  ];
  return all.where((m) => m.visible).toList();
}

bool get hasOpsAccess => visibleOpsModules().isNotEmpty;
