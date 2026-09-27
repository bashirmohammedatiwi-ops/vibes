import {
  KycStatus,
  NotificationType,
  PrismaClient,
  PropertyStatus,
  PropertyType,
  UserRole,
} from '@prisma/client';

const prisma = new PrismaClient();

const IRAQ_PROVINCES: Array<{
  slug: string;
  nameAr: string;
  nameEn: string;
  cities: Array<{ slug: string; nameAr: string; nameEn: string }>;
}> = [
  {
    slug: 'baghdad',
    nameAr: 'بغداد',
    nameEn: 'Baghdad',
    cities: [
      { slug: 'baghdad', nameAr: 'بغداد', nameEn: 'Baghdad' },
      { slug: 'karkh', nameAr: 'الكرخ', nameEn: 'Karkh' },
      { slug: 'rusafa', nameAr: 'الرصافة', nameEn: 'Rusafa' },
    ],
  },
  {
    slug: 'basra',
    nameAr: 'البصرة',
    nameEn: 'Basra',
    cities: [{ slug: 'basra', nameAr: 'البصرة', nameEn: 'Basra' }],
  },
  {
    slug: 'nineveh',
    nameAr: 'نينوى',
    nameEn: 'Nineveh',
    cities: [{ slug: 'mosul', nameAr: 'الموصل', nameEn: 'Mosul' }],
  },
  {
    slug: 'erbil',
    nameAr: 'أربيل',
    nameEn: 'Erbil',
    cities: [{ slug: 'erbil', nameAr: 'أربيل', nameEn: 'Erbil' }],
  },
  {
    slug: 'sulaymaniyah',
    nameAr: 'السليمانية',
    nameEn: 'Sulaymaniyah',
    cities: [{ slug: 'sulaymaniyah', nameAr: 'السليمانية', nameEn: 'Sulaymaniyah' }],
  },
  {
    slug: 'duhok',
    nameAr: 'دهوك',
    nameEn: 'Duhok',
    cities: [{ slug: 'duhok', nameAr: 'دهوك', nameEn: 'Duhok' }],
  },
  {
    slug: 'kirkuk',
    nameAr: 'كركوك',
    nameEn: 'Kirkuk',
    cities: [{ slug: 'kirkuk', nameAr: 'كركوك', nameEn: 'Kirkuk' }],
  },
  {
    slug: 'anbar',
    nameAr: 'الأنبار',
    nameEn: 'Anbar',
    cities: [{ slug: 'ramadi', nameAr: 'الرمادي', nameEn: 'Ramadi' }],
  },
  {
    slug: 'saladin',
    nameAr: 'صلاح الدين',
    nameEn: 'Saladin',
    cities: [{ slug: 'tikrit', nameAr: 'تكريت', nameEn: 'Tikrit' }],
  },
  {
    slug: 'diyala',
    nameAr: 'ديالى',
    nameEn: 'Diyala',
    cities: [{ slug: 'baqubah', nameAr: 'بعقوبة', nameEn: 'Baqubah' }],
  },
  {
    slug: 'wasit',
    nameAr: 'واسط',
    nameEn: 'Wasit',
    cities: [{ slug: 'kut', nameAr: 'الكوت', nameEn: 'Kut' }],
  },
  {
    slug: 'babylon',
    nameAr: 'بابل',
    nameEn: 'Babylon',
    cities: [{ slug: 'hilla', nameAr: 'الحلة', nameEn: 'Hilla' }],
  },
  {
    slug: 'karbala',
    nameAr: 'كربلاء',
    nameEn: 'Karbala',
    cities: [{ slug: 'karbala', nameAr: 'كربلاء', nameEn: 'Karbala' }],
  },
  {
    slug: 'najaf',
    nameAr: 'النجف',
    nameEn: 'Najaf',
    cities: [{ slug: 'najaf', nameAr: 'النجف', nameEn: 'Najaf' }],
  },
  {
    slug: 'qadisiyyah',
    nameAr: 'القادسية',
    nameEn: 'Qadisiyyah',
    cities: [{ slug: 'diwaniyah', nameAr: 'الديوانية', nameEn: 'Diwaniyah' }],
  },
  {
    slug: 'muthanna',
    nameAr: 'المثنى',
    nameEn: 'Muthanna',
    cities: [{ slug: 'samawah', nameAr: 'السماوة', nameEn: 'Samawah' }],
  },
  {
    slug: 'dhi-qar',
    nameAr: 'ذي قار',
    nameEn: 'Dhi Qar',
    cities: [{ slug: 'nasiriyah', nameAr: 'الناصرية', nameEn: 'Nasiriyah' }],
  },
  {
    slug: 'maysan',
    nameAr: 'ميسان',
    nameEn: 'Maysan',
    cities: [{ slug: 'amarah', nameAr: 'العمارة', nameEn: 'Amarah' }],
  },
];

const SYSTEM_AMENITIES: Array<{
  slug: string;
  nameAr: string;
  nameEn: string;
  icon: string;
  category: string;
  appliesTo: PropertyType[];
}> = [
  { slug: 'pool', nameAr: 'مسبح', nameEn: 'Swimming pool', icon: '🏊', category: 'ترفيه', appliesTo: [PropertyType.FARM] },
  { slug: 'bbq', nameAr: 'منطقة شواء', nameEn: 'BBQ area', icon: '🍖', category: 'ترفيه', appliesTo: [PropertyType.FARM] },
  { slug: 'outdoor-seating', nameAr: 'جلسات خارجية', nameEn: 'Outdoor seating', icon: '⛺', category: 'ترفيه', appliesTo: [PropertyType.FARM] },
  { slug: 'river-view', nameAr: 'إطلالة نهر', nameEn: 'River view', icon: '🌊', category: 'عام', appliesTo: [PropertyType.FARM] },
  { slug: 'garden', nameAr: 'حديقة', nameEn: 'Garden', icon: '🌳', category: 'عام', appliesTo: [PropertyType.FARM] },
  { slug: 'kids-playground', nameAr: 'ملعب أطفال', nameEn: 'Kids playground', icon: '🛝', category: 'ترفيه', appliesTo: [PropertyType.FARM] },
  { slug: 'wifi', nameAr: 'واي فاي', nameEn: 'Wi-Fi', icon: '📶', category: 'تقنيات', appliesTo: [PropertyType.FARM, PropertyType.HALL] },
  { slug: 'generator', nameAr: 'مولد كهرباء', nameEn: 'Power generator', icon: '⚡', category: 'تقنيات', appliesTo: [PropertyType.FARM, PropertyType.HALL] },
  { slug: 'ac', nameAr: 'تكييف', nameEn: 'Air conditioning', icon: '❄️', category: 'تقنيات', appliesTo: [PropertyType.FARM, PropertyType.HALL] },
  { slug: 'kitchen', nameAr: 'مطبخ', nameEn: 'Kitchen', icon: '🍳', category: 'خدمات', appliesTo: [PropertyType.FARM, PropertyType.HALL] },
  { slug: 'parking', nameAr: 'مواقف سيارات', nameEn: 'Parking', icon: '🅿️', category: 'خدمات', appliesTo: [PropertyType.FARM, PropertyType.HALL, PropertyType.DECORATION] },
  { slug: 'prayer-room', nameAr: 'مصلى', nameEn: 'Prayer room', icon: '🕌', category: 'خدمات', appliesTo: [PropertyType.HALL, PropertyType.FARM] },
  { slug: 'stage', nameAr: 'منصة وكوش', nameEn: 'Stage & Kush', icon: '🎪', category: 'عام', appliesTo: [PropertyType.HALL] },
  { slug: 'sound-system', nameAr: 'نظام صوتي', nameEn: 'Sound system', icon: '🔊', category: 'تقنيات', appliesTo: [PropertyType.HALL] },
  { slug: 'screens', nameAr: 'شاشات عرض', nameEn: 'Display screens', icon: '📺', category: 'تقنيات', appliesTo: [PropertyType.HALL] },
  { slug: 'catering', nameAr: 'ضيافة وتقديم طعام', nameEn: 'Catering', icon: '☕', category: 'خدمات', appliesTo: [PropertyType.HALL] },
  { slug: 'photography', nameAr: 'تصوير', nameEn: 'Photography', icon: '📷', category: 'خدمات', appliesTo: [PropertyType.HALL, PropertyType.DECORATION] },
  { slug: 'central-ac', nameAr: 'تكييف مركزي', nameEn: 'Central AC', icon: '❄️', category: 'تقنيات', appliesTo: [PropertyType.HALL] },
  { slug: 'kush', nameAr: 'كوش أعراس', nameEn: 'Wedding Kush', icon: '💐', category: 'عام', appliesTo: [PropertyType.DECORATION] },
  { slug: 'fresh-flowers', nameAr: 'ورد طبيعي', nameEn: 'Fresh flowers', icon: '🌹', category: 'عام', appliesTo: [PropertyType.DECORATION] },
  { slug: 'artificial-flowers', nameAr: 'ورد صناعي', nameEn: 'Artificial flowers', icon: '🌸', category: 'عام', appliesTo: [PropertyType.DECORATION] },
  { slug: 'decor-lighting', nameAr: 'إضاءة ديكور', nameEn: 'Decorative lighting', icon: '✨', category: 'تقنيات', appliesTo: [PropertyType.DECORATION] },
  { slug: 'photo-backdrop', nameAr: 'خلفيات تصوير', nameEn: 'Photo backdrop', icon: '🖼️', category: 'عام', appliesTo: [PropertyType.DECORATION] },
  { slug: 'setup-teardown', nameAr: 'تركيب وفك', nameEn: 'Setup & teardown', icon: '🔧', category: 'خدمات', appliesTo: [PropertyType.DECORATION] },
];

async function seedAmenities() {
  for (const [index, amenity] of SYSTEM_AMENITIES.entries()) {
    await prisma.amenity.upsert({
      where: { slug: amenity.slug },
      update: {
        nameAr: amenity.nameAr,
        nameEn: amenity.nameEn,
        icon: amenity.icon,
        category: amenity.category,
        appliesTo: amenity.appliesTo,
        isSystem: true,
        sortOrder: index,
      },
      create: {
        slug: amenity.slug,
        nameAr: amenity.nameAr,
        nameEn: amenity.nameEn,
        icon: amenity.icon,
        category: amenity.category,
        appliesTo: amenity.appliesTo,
        isSystem: true,
        sortOrder: index,
      },
    });
  }
}

/** Mirrors legacy amenities JSON into PropertyAmenity rows (idempotent). */
async function syncPropertyAmenityRows() {
  const amenities = await prisma.amenity.findMany();
  const byName = new Map(amenities.map((a) => [a.nameAr, a.id]));
  const properties = await prisma.property.findMany({ select: { id: true, amenities: true } });

  for (const property of properties) {
    const names = Array.isArray(property.amenities) ? (property.amenities as string[]) : [];
    const links = names
      .map((name, sortOrder) => ({ amenityId: byName.get(name), sortOrder }))
      .filter((link): link is { amenityId: string; sortOrder: number } => !!link.amenityId);
    if (!links.length) continue;
    await prisma.propertyAmenity.createMany({
      data: links.map((link) => ({ propertyId: property.id, ...link })),
      skipDuplicates: true,
    });
  }
}

async function main() {
  await seedAmenities();

  for (const province of IRAQ_PROVINCES) {
    await prisma.province.upsert({
      where: { slug: province.slug },
      update: { nameAr: province.nameAr, nameEn: province.nameEn },
      create: {
        slug: province.slug,
        nameAr: province.nameAr,
        nameEn: province.nameEn,
        cities: { create: province.cities },
      },
    });
  }

  const adminPhone = process.env.ADMIN_PHONE ?? '9647700000000';
  const admin = await prisma.user.upsert({
    where: { phone: adminPhone },
    update: { role: UserRole.ADMIN, name: process.env.ADMIN_NAME ?? 'VIBES Admin' },
    create: {
      phone: adminPhone,
      name: process.env.ADMIN_NAME ?? 'VIBES Admin',
      role: UserRole.ADMIN,
    },
  });

  const providerUser = await prisma.user.upsert({
    where: { phone: '9647700000001' },
    update: { role: UserRole.PROVIDER, name: 'مالك تجريبي' },
    create: {
      phone: '9647700000001',
      name: 'مالك تجريبي',
      role: UserRole.PROVIDER,
    },
  });

  const provider = await prisma.provider.upsert({
    where: { userId: providerUser.id },
    update: { verified: true, kycStatus: KycStatus.VERIFIED, businessName: 'مزارع ومناسبات النخيل' },
    create: {
      userId: providerUser.id,
      verified: true,
      kycStatus: KycStatus.VERIFIED,
      businessName: 'مزارع ومناسبات النخيل',
    },
  });

  const baghdad = await prisma.city.findFirst({
    where: { slug: 'baghdad', province: { slug: 'baghdad' } },
  });
  const erbil = await prisma.city.findFirst({
    where: { slug: 'erbil', province: { slug: 'erbil' } },
  });
  const basra = await prisma.city.findFirst({
    where: { slug: 'basra', province: { slug: 'basra' } },
  });

  if (!baghdad || !erbil || !basra) {
    throw new Error('Seed cities missing');
  }

  const staff = await prisma.user.upsert({
    where: { phone: '9647700000002' },
    update: { role: UserRole.STAFF, name: 'فريق VIBES' },
    create: {
      phone: '9647700000002',
      name: 'فريق VIBES',
      role: UserRole.STAFF,
    },
  });

  const samples: Array<{
    name: string;
    slug: string;
    type: PropertyType;
    cityId: string;
    lat: number;
    lng: number;
    price: string;
    capacity: number;
    amenities: string[];
    description: string;
  }> = [
    {
      name: 'مزرعة النخيل',
      slug: 'mzr-annkhyl',
      type: PropertyType.FARM,
      cityId: baghdad.id,
      lat: 33.3152,
      lng: 44.3661,
      price: '250000',
      capacity: 80,
      amenities: ['مسبح', 'مولد كهرباء', 'كراج', 'شواء', 'واي فاي'],
      description: 'مزرعة واسعة على أطراف بغداد مع مسبح وحديقة نخيل.',
    },
    {
      name: 'مزرعة دجلة',
      slug: 'mzr-djlh',
      type: PropertyType.FARM,
      cityId: baghdad.id,
      lat: 33.223,
      lng: 44.366,
      price: '180000',
      capacity: 50,
      amenities: ['نهر', 'شواء', 'كراج', 'مكيف'],
      description: 'إطلالة على النهر وجلسات خارجية للعائلات.',
    },
    {
      name: 'شاليه أربيل هيلز',
      slug: 'shaly-arbyl-hylz',
      type: PropertyType.FARM,
      cityId: erbil.id,
      lat: 36.1911,
      lng: 44.0091,
      price: '320000',
      capacity: 40,
      amenities: ['مسبح', 'تكييف', 'واي فاي', 'مطبخ'],
      description: 'شاليه حديث قرب أربيل مناسب للعطل القصيرة.',
    },
    {
      name: 'قاعة الياسمين',
      slug: 'qa-alyasmyn',
      type: PropertyType.HALL,
      cityId: baghdad.id,
      lat: 33.3406,
      lng: 44.4009,
      price: '1500000',
      capacity: 400,
      amenities: ['مكيف', 'إضاءة', 'منصة', 'مواقف', 'مولد'],
      description: 'قاعة أعراس في بغداد تتسع لـ 400 ضيف.',
    },
    {
      name: 'قاعة البصرة الكبرى',
      slug: 'qa-albsr-alkbr',
      type: PropertyType.HALL,
      cityId: basra.id,
      lat: 30.5081,
      lng: 47.7835,
      price: '900000',
      capacity: 250,
      amenities: ['مكيف', 'ديكور أساسي', 'مواقف', 'صوتيات'],
      description: 'قاعة مناسبات في قلب البصرة.',
    },
  ];

  for (const sample of samples) {
    const existing = await prisma.property.findFirst({
      where: { OR: [{ name: sample.name }, { slug: sample.slug }] },
    });
    if (existing) {
      await prisma.property.update({
        where: { id: existing.id },
        data: {
          slug: sample.slug,
          createdById: admin.id,
          featured: sample.name.includes('النخيل') || sample.name.includes('الياسمين'),
          publishedAt: new Date(),
        },
      });
      continue;
    }

    await prisma.property.create({
      data: {
        createdById: admin.id,
        type: sample.type,
        slug: sample.slug,
        name: sample.name,
        description: sample.description,
        cityId: sample.cityId,
        address: 'عنوان تجريبي',
        latitude: sample.lat,
        longitude: sample.lng,
        capacity: sample.capacity,
        pricePerDay: sample.price,
        amenities: sample.amenities,
        status: PropertyStatus.APPROVED,
        featured: sample.name.includes('النخيل') || sample.name.includes('الياسمين'),
        publishedAt: new Date(),
        phone: '9647700000000',
      },
    });
  }

  const decorationExisting = await prisma.property.findFirst({ where: { slug: 'dekor-alf-rakh' } });
  if (!decorationExisting && baghdad) {
    await prisma.property.create({
      data: {
        createdById: admin.id,
        type: PropertyType.DECORATION,
        slug: 'dekor-alf-rakh',
        name: 'ديكور الفرح',
        description: 'خدمات ديكور كامل للأعراس والمناسبات في بغداد.',
        cityId: baghdad.id,
        address: 'بغداد — الكرادة',
        latitude: 33.3128,
        longitude: 44.3615,
        capacity: 500,
        pricePerDay: '750000',
        amenities: ['ورد طبيعي', 'إضاءة', 'كوشة', 'تركيب'],
        tags: ['أعراس', 'VIP'],
        status: PropertyStatus.APPROVED,
        featured: true,
        publishedAt: new Date(),
        phone: '9647700000000',
      },
    });
  }

  const customer = await prisma.user.upsert({
    where: { phone: '9647700000003' },
    update: { name: 'عميل تجريبي' },
    create: { phone: '9647700000003', name: 'عميل تجريبي', role: UserRole.CUSTOMER },
  });

  const farm = await prisma.property.findFirst({ where: { slug: 'mzr-annkhyl' } });
  if (farm) {
    const today = new Date();
    for (let i = 0; i < 14; i++) {
      const date = new Date(today);
      date.setDate(today.getDate() + i);
      await prisma.availabilitySlot.upsert({
        where: {
          propertyId_date_shift: { propertyId: farm.id, date, shift: 'FULL' },
        },
        update: {},
        create: { propertyId: farm.id, date, shift: 'FULL', isAvailable: i % 7 !== 5 },
      });
    }

    await prisma.review.upsert({
      where: { userId_propertyId: { userId: customer.id, propertyId: farm.id } },
      update: { rating: 5, comment: 'مزرعة رائعة وخدمة ممتازة!' },
      create: {
        userId: customer.id,
        propertyId: farm.id,
        rating: 5,
        comment: 'مزرعة رائعة وخدمة ممتازة!',
      },
    });

    await prisma.property.update({
      where: { id: farm.id },
      data: { ratingAvg: 5, ratingCount: 1 },
    });

    const start = new Date();
    start.setDate(start.getDate() + 10);
    const end = new Date(start);
    end.setDate(end.getDate() + 2);

    const bookingExists = await prisma.booking.findFirst({
      where: { userId: customer.id, propertyId: farm.id },
    });
    if (!bookingExists) {
      await prisma.booking.create({
        data: {
          userId: customer.id,
          propertyId: farm.id,
          startDate: start,
          endDate: end,
          guests: 40,
          status: 'PENDING',
          totalPrice: Number(farm.pricePerDay) * 2,
          notes: 'حجز تجريبي من seed',
          payment: {
            create: {
              method: 'MANUAL',
              amount: Number(farm.pricePerDay) * 2,
              status: 'PENDING',
            },
          },
        },
      });
    }
  }

  const freshPlaces: Array<{
    name: string;
    slug: string;
    type: PropertyType;
    cityId: string;
    lat: number;
    lng: number;
    price: string;
    capacity: number;
    description: string;
    cover: string;
    banner: string;
    spotlightTitle: string;
    height: number;
  }> = [
    {
      name: 'مزرعة الرافدين',
      slug: 'mzr-alrafdyn',
      type: PropertyType.FARM,
      cityId: baghdad.id,
      lat: 33.289,
      lng: 44.412,
      price: '210000',
      capacity: 60,
      description: 'مزرعة جديدة على ضفاف دجلة، جلسات ونخيل ومسبح عائلي.',
      cover: 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&h=1600&q=80',
      banner: 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1600&h=700&q=80',
      spotlightTitle: 'مزرعة الرافدين',
      height: 176,
    },
    {
      name: 'مزرعة السدير',
      slug: 'mzr-alsdyr',
      type: PropertyType.FARM,
      cityId: baghdad.id,
      lat: 33.41,
      lng: 44.36,
      price: '165000',
      capacity: 45,
      description: 'مزرعة حديثة بحديقة واسعة ومنطقة شواء للعائلات.',
      cover: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?auto=format&fit=crop&w=1200&h=1600&q=80',
      banner: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?auto=format&fit=crop&w=1600&h=700&q=80',
      spotlightTitle: 'مزرعة السدير',
      height: 168,
    },
    {
      name: 'قاعة القصر',
      slug: 'qa-alqsr',
      type: PropertyType.HALL,
      cityId: baghdad.id,
      lat: 33.352,
      lng: 44.42,
      price: '1800000',
      capacity: 500,
      description: 'قاعة جديدة للمناسبات الكبرى، منصة وإضاءة ومواقف واسعة.',
      cover: 'https://images.unsplash.com/photo-1519167758481-83f29da8c2b0?auto=format&fit=crop&w=1200&h=1600&q=80',
      banner: 'https://images.unsplash.com/photo-1519167758481-83f29da8c2b0?auto=format&fit=crop&w=1600&h=700&q=80',
      spotlightTitle: 'قاعة القصر',
      height: 200,
    },
    {
      name: 'قاعة النور',
      slug: 'qa-alnr',
      type: PropertyType.HALL,
      cityId: basra.id,
      lat: 30.52,
      lng: 47.79,
      price: '1100000',
      capacity: 280,
      description: 'قاعة جديدة في البصرة لأعراس المساء والولائم.',
      cover: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1200&h=1600&q=80',
      banner: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1600&h=700&q=80',
      spotlightTitle: 'قاعة النور',
      height: 184,
    },
  ];

  for (const [index, place] of freshPlaces.entries()) {
    const property = await prisma.property.upsert({
      where: { slug: place.slug },
      update: {
        name: place.name,
        type: place.type,
        isNew: true,
        status: PropertyStatus.APPROVED,
        publishedAt: new Date(),
        description: place.description,
      },
      create: {
        createdById: admin.id,
        type: place.type,
        slug: place.slug,
        name: place.name,
        description: place.description,
        cityId: place.cityId,
        address: 'عنوان تجريبي',
        latitude: place.lat,
        longitude: place.lng,
        capacity: place.capacity,
        pricePerDay: place.price,
        status: PropertyStatus.APPROVED,
        isNew: true,
        featured: false,
        publishedAt: new Date(),
        phone: '9647700000000',
      },
    });

    const cover = await prisma.media.findFirst({
      where: { propertyId: property.id, isPrimary: true },
    });
    if (!cover) {
      await prisma.media.create({
        data: {
          propertyId: property.id,
          url: place.cover,
          type: 'IMAGE',
          status: 'READY',
          isPrimary: true,
          width: 1200,
          height: 1600,
          altText: place.name,
        },
      });
    }

    const spotlight = await prisma.homeSpotlight.findFirst({
      where: { propertyId: property.id },
    });
    if (!spotlight) {
      await prisma.homeSpotlight.create({
        data: {
          title: place.spotlightTitle,
          imageUrl: place.banner,
          propertyId: property.id,
          height: place.height,
          sortOrder: index,
          isActive: true,
        },
      });
    }
  }

  const bannerCount = await prisma.banner.count();
  if (bannerCount === 0) {
    await prisma.banner.createMany({
      data: [
        {
          title: 'اكتشف أجمل المزارع',
          subtitle: 'حجز فوري — أسعار شفافة',
          imageUrl: 'https://picsum.photos/seed/vibes-farm/1200/600',
          linkUrl: '/search?type=FARM',
          sortOrder: 0,
        },
        {
          title: 'قاعات أفراح فاخرة',
          subtitle: 'بغداد · البصرة · أربيل',
          imageUrl: 'https://picsum.photos/seed/vibes-hall/1200/600',
          sortOrder: 1,
        },
      ],
    });
  }

  // Demo coupon so promotions are visible right after setup.
  await prisma.coupon.upsert({
    where: { code: 'VIBES10' },
    update: {},
    create: {
      code: 'VIBES10',
      description: 'خصم ترحيبي 10% لعملاء VIBES',
      discountType: 'PERCENT',
      discountValue: '10',
      maxUsesPerUser: 1,
      isActive: true,
    },
  });

  const demoBooking = await prisma.booking.findFirst({
    where: { userId: customer.id },
    include: { payment: true, property: true },
  });
  if (demoBooking) {
    await prisma.conversation.upsert({
      where: { bookingId: demoBooking.id },
      update: {},
      create: {
        bookingId: demoBooking.id,
        kind: 'BOOKING',
        participants: {
          create: [{ userId: customer.id }, { userId: providerUser.id }],
        },
        messages: {
          create: [
            { kind: 'SYSTEM', body: `بدأت محادثة حجز ${demoBooking.property.name}` },
            {
              kind: 'TEXT',
              senderId: customer.id,
              body: 'مرحباً، هل المسبح جاهز في ذلك اليوم؟',
            },
          ],
        },
      },
    });

    await prisma.invoice.upsert({
      where: { bookingId: demoBooking.id },
      update: {},
      create: {
        bookingId: demoBooking.id,
        number: `VIB-${new Date().getFullYear()}-00001`,
        status: 'ISSUED',
        subtotal: demoBooking.totalPrice,
        discount: 0,
        total: demoBooking.totalPrice,
        items: [
          { label: `إقامة — ${demoBooking.property.name}`, amount: Number(demoBooking.totalPrice) },
        ],
      },
    });

    await prisma.userNotification.createMany({
      data: [
        {
          userId: customer.id,
          type: 'BOOKING',
          title: 'تم استلام حجزك',
          body: `${demoBooking.property.name} — بانتظار التأكيد`,
          linkUrl: `/booking/${demoBooking.id}`,
          entityType: 'booking',
          entityId: demoBooking.id,
        },
        {
          userId: providerUser.id,
          type: 'MESSAGE',
          title: 'رسالة جديدة',
          body: 'مرحباً، هل المسبح جاهز في ذلك اليوم؟',
          linkUrl: `/conversations`,
          entityType: 'booking',
          entityId: demoBooking.id,
        },
      ],
    });
  }

  const defaultCollection = await prisma.collection.findFirst({
    where: { userId: customer.id, isDefault: true },
  });
  if (!defaultCollection) {
    await prisma.collection.create({
      data: { userId: customer.id, name: 'محفوظاتي', isDefault: true },
    });
  }

  await prisma.providerFollow.upsert({
    where: { userId_providerId: { userId: customer.id, providerId: provider.id } },
    update: {},
    create: { userId: customer.id, providerId: provider.id },
  });

  let completedBooking = await prisma.booking.findFirst({
    where: { userId: customer.id, status: 'COMPLETED' },
  });
  if (!completedBooking && farm) {
    const pastStart = new Date();
    pastStart.setDate(pastStart.getDate() - 14);
    const pastEnd = new Date(pastStart);
    pastEnd.setDate(pastEnd.getDate() + 2);
    completedBooking = await prisma.booking.create({
      data: {
        userId: customer.id,
        propertyId: farm.id,
        startDate: pastStart,
        endDate: pastEnd,
        guests: 12,
        status: 'COMPLETED',
        totalPrice: Number(farm.pricePerDay) * 2,
        notes: 'حجز مكتمل لتجربة اجتماعية',
        payment: {
          create: {
            method: 'MANUAL',
            amount: Number(farm.pricePerDay) * 2,
            status: 'PAID',
          },
        },
      },
    });
  }
  if (completedBooking) {
    await prisma.socialPost.upsert({
      where: { bookingId: completedBooking.id },
      update: {},
      create: {
        userId: customer.id,
        bookingId: completedBooking.id,
        propertyId: completedBooking.propertyId,
        caption: 'يوم عائلي رائع — أنصح بالمكان بشدة',
        mediaUrls: ['https://picsum.photos/seed/vibes-exp/900/1200'],
        status: 'PUBLISHED',
      },
    });
  }

  await syncPropertyAmenityRows();

  await prisma.adminActivity.create({
    data: {
      userId: admin.id,
      action: 'seed.complete',
      entityType: 'system',
      metadata: { version: '0.4.0' },
    },
  });

  await prisma.teamNotification.create({
    data: {
      type: NotificationType.SYSTEM,
      title: 'مرحباً بفريق VIBES',
      body: 'لوحة التحكم جاهزة — ابدأ بإضافة الأماكن والصور',
      linkUrl: '/properties/new',
    },
  });

  // eslint-disable-next-line no-console
  console.log(
    `Seeded VIBES. Admin: ${admin.phone} | Staff: ${staff.phone} | OTP: 123456`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
