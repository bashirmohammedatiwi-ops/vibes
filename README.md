# VIBES

منصة حجز المزارع وقاعات الأعراس وخدمات التزيين في العراق.

## الهيكل

```
vibes/
├── apps/
│   ├── mobile/     # Flutter (iOS / Android)
│   ├── api/        # NestJS + Prisma
│   └── admin/      # Next.js admin panel
├── docker/
│   ├── nginx/
│   └── postgres/init.sql
├── docker-compose.yml
├── docker-compose.prod.yml
└── .env.example
```

## المتطلبات

- [Docker](https://docs.docker.com/get-docker/) و Docker Compose
- [Node.js 20+](https://nodejs.org/)
- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- Git

للتطوير بدون Docker تحتاج أيضاً PostgreSQL 16 مع PostGIS و Redis 7.

## التشغيل السريع (Docker)

```bash
cp .env.example .env
docker compose up --build
```

بعد التشغيل:

| الخدمة | الرابط |
|--------|--------|
| API | http://localhost:3000 |
| Health | http://localhost:3000/health |
| Swagger | http://localhost:3000/api/docs |
| Admin | http://localhost:3001 |
| Nginx | http://localhost (`/api`, `/admin`, `/media`) |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

تطبيق الـ migrations والـ seed داخل حاوية الـ API:

```bash
docker compose exec api npx prisma migrate deploy
docker compose exec api npx prisma db seed
```

## تشغيل محلي بدون Docker (PostgreSQL + Redis من Homebrew)

على جهاز التطوير الحالي يعمل الـ stack هكذا:

```bash
# 1) تشغيل الخدمات إن لم تكن تعمل
pg_ctl -D /opt/homebrew/var/postgresql@16 start
redis-server --port 6379 --daemonize yes --bind 127.0.0.1

# 2) قاعدة البيانات (مرة واحدة)
# المستخدم: vibes / كلمة المرور: vibes_dev_password / قاعدة: vibes

# 3) API
cd apps/api
# .env جاهز بـ localhost
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```

لوحة الإدارة في طرفية ثانية:

```bash
cd apps/admin
npm run dev
```

روابط التحقق بعد التشغيل:

| الخدمة | الرابط | النتيجة المتوقعة |
|--------|--------|-------------------|
| Health | http://localhost:3000/health | `{"status":"ok"}` |
| Swagger | http://localhost:3000/api/docs | 200 |
| الأماكن | http://localhost:3000/api/properties | 5 أماكن تجريبية |
| Admin | http://localhost:3001/login | 200 |

دخول الإدارة: `9647700000000` / OTP `123456`

PostGIS اختياري محلياً (البحث الجغرافي يستخدم إحداثيات lat/lng). صورة Docker `postgis/postgis` تفعّله على الـ VPS.

## تطبيق Flutter — VIBES Élégance

تطبيق واحد للزبون والمزوّد بلغة تصميم راقية (حبر + بورسلان + ذهبي شامبانيا واحداً فقط):

```bash
cd apps/mobile
flutter pub get
flutter run
```

عنوان الـ API الافتراضي في التطبيق: `http://localhost:3000` (محاكي iOS) أو `http://10.0.2.2:3000` (محاكي Android). غيّره من `lib/core/constants/api_constants.dart` أو بـ `--dart-define=API_URL=...`.

### تجربة الزبون
- تحية مسرحية + بانرات + تصنيفات + «مميز» أفقي + الأعلى تقييماً
- **تبويب الاستكشاف (ريلز)**: تدفّق عمودي 9:16 بتشغيل صامت تلقائي وزر حجز ذهبي (`GET /api/reels`)
- بحث بفلاتر (نوع/سعة/سعر/فرز) بورقة سفلية أنيقة
- صفحة مكان غامرة: معرض صور/فيديو/**جولات 360°** ببارالاكس، مزايا بالأيقونات، **شريط أسعار الأيام** (قواعد الأسعار)، تقييمات، بطاقة مالك
- مفضلة بالحساب (`/api/favorites`) بقلب نابض متزامن
- حجز بـ **quote حي وكوبون فوري** (`/api/bookings/quote-coupon`) + إثبات دفع بالكاميرا + خط زمني للحالة

### نافذة المزوّد (دور PROVIDER بعد الـ OTP)
لوحة KPIs بذهبي داكن · حجوزاته بتأكيد/إلغاء وتواصل بالضيف · تقويم شهري بعلامات وحظر أيام · ممتلكاته (الأسعار/الوسائط/التوفر) · أرباح برسم أعمدة شهري — كلها عبر `/api/provider/*` المحصور بملكيته.

### البنية
Riverpod + go_router (StatefulShellRoute بتبويبات محفوظة وحارس أدوار) + Dio (401 → تحديث تلقائي) + موديلات مكتوبة كاملة + مكتبة ويدجت Élégance (VibesButton/GlassCard/StatusPill/DayPriceStrip…). الوضع الداكن افتراضي مع مبدّل.

## لوحة الإدارة

```bash
cd apps/admin
npm install
npm run dev
```

تفتح على http://localhost:3001

دخول تجريبي بعد الـ seed: رقم `9647700000000` ورمز OTP `123456` (وضع التطوير فقط). المزود التجريبي `9647700000001` يدخل بوابة المالك على `/provider`.

## القدرات الجديدة (v0.4)

- **تصميم VIBES Nova (لوحة التحكم)**: طبقة `vibes-nova.css` تعيد تشكيل الهوية البصرية — سيدار قيادة داكن بتوهج شفق، خلفية متدرجة ناعمة، توبار زجاجي مع شريحة تاريخ عربية، بطاقة ترحيب متدرجة داكنة، أزرار بتدرج ولمعة متحركة، رؤوس جداول لاصقة بأحرف كبيرة، شريط جوال زجاجي عائم، صفحة دخول بلوحة تعريفية داكنة، حركات دخول متدرجة، أنماط طباعة نظيفة، وتوافق كامل مع الوضع الليلي وRTL.
- **محرك تسعير مرن لكل عقار**: قواعد «مجموعة أيام» (مثال: الخميس والجمعة بسعر مختلف) وقواعد «فترات/مواسم» بتواريخ شاملة، بأولويات حسم واضحة (تجاوز اليوم > الفترة > الأسبوعية > الافتراضي)، مع أوقات شفت مخصصة لكل عقار (مثال رمضان) ووضع حجز لكل نوع: `FULL_DAY` / `SHIFTS` / `HYBRID` — القاعات يمكنها شفتان يومياً عبر `SHIFTS` أو `HYBRID`. معاينة حية بسعر كل يوم من `GET /api/admin/properties/:id/pricing-preview`.
- **كتالوج مزايا مقسّم حسب النوع**: صفحة «المزايا» في اللوحة + `AmenityPicker` في نموذج العقار يعرض لكل نوع مزاياه فقط؛ ترحيل تلقائي من حقل JSON القديم إلى صفوف علائقية مع إبقاء JSON كمرآة للتوافق مع الموبايل.
- **فيديو بمختلف النسب**: رفع حتى `MEDIA_VIDEO_MAX_MB`، معالجة تلقائية عبر BullMQ + ffmpeg (Docker) لاستخراج الملصق والأبعاد والنسبة ونسخ 720p ونسخة مقصوصة بالنسبة المطلوبة (1:1 / 16:9 / 9:16 / 4:3) — طبقة تجريد `StorageDriver`/`TranscodeDriver` مع تنفيذ `BunnyStreamTranscodeDriver` جاهز لتفعيله ببديل `MEDIA_TRANSCODE_DRIVER=bunny`.
- **كوبونات وعروض**: نسبة أو مبلغ، حدود استخدام كلية/لكل مستخدم، فترة صلاحية، حصر بالأنواع أو مكان محدد، خصم ذري آمن ضمن معاملة الحجز (تبويب «الكوبونات» + حقل الرمز في الحجز اليدوي وquote).
- **بوابة المزود (المالك)**: دخول دور `PROVIDER` للوحة على `/provider` — نظرة عامة وأرباح 6 أشهر، حجوزاته بتأكيد/إلغاء، إدارة أسعار وتوفر ممتلكاته عبر `PATCH/GET /api/provider/*` بحصر إجباري بملكيته.
- **تحليلات متقدمة**: صفحة «التحليلات» — اتجاه الإيراد اليومي مع مقارنة الفترة السابقة، إشغال تقريبي، معدل إلغاء، مهلة حجز مسبق، أفضل المزودين، تصدير CSV.
- **إشعارات**: داخل اللوحة (موجود) + واتساب لملاك الأماكن عند الحجز/تغيّر الحالة بمفتاح تشغيل في الإعدادات (`notify_whatsapp_enabled`) + جدول `device_tokens` لتسجيل أجهزة FCM لإشعارات Push لاحقاً (`POST /api/devices`).

ملاحظة توافق الموبايل: كل استجابات API القديمة تعمل كما هي؛ الحقول الجديدة إضافية، وسعر quote الجديد يعكس القواعد تلقائياً.

## المتغيرات البيئية

انسخ [`.env.example`](.env.example) إلى `.env`. أهم المتغيرات:

- `DATABASE_URL` — PostgreSQL
- `REDIS_URL` — Redis (جلسات OTP والـ cache)
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`
- `OTP_PROVIDER=development` يرجع OTP ثابت `123456` في التطوير
- `OTP_PROVIDER=whatsapp` يرسل الرمز عبر WhatsApp Cloud API (يتطلب `WHATSAPP_PHONE_NUMBER_ID` و`WHATSAPP_ACCESS_TOKEN` وقالب رسالة معتمد من Meta)
- `MEDIA_VIDEO_MAX_MB=200` سقف رفع الفيديو، و`MEDIA_TRANSCODE_DRIVER=ffmpeg` (محلي) أو `bunny` (Bunny Stream — يتطلب مفاتيحه أدناه)
- Firebase / Mapbox / Bunny / R2: placeholders للمرحلة 2

## النشر على Hostinger KVM 2

1. ثبّت Docker و Docker Compose على Ubuntu.
2. انسخ المشروع وارفع `.env` بقيم الإنتاج.
3. شغّل:

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec api npx prisma migrate deploy
docker compose -f docker-compose.prod.yml exec api npx prisma db seed
```

4. وجّه Cloudflare DNS إلى IP الـ VPS.
5. فعّل SSL عبر Certbot (انظر `docker/nginx/README.md`).

حدود الذاكرة مضبوطة لخطة KVM 2 (8 GB RAM).

## التوثيق

- واجهة الـ API: `/api/docs` بعد تشغيل NestJS
- مخطط قاعدة البيانات: `apps/api/prisma/schema.prisma`

## التحقق من البناء (محلياً)

| المكوّن | الأمر | الحالة |
|---------|-------|--------|
| API tests + lint | `cd apps/api && npm test && npm run lint && npm run build` | نجح |
| Admin production build | `cd apps/admin && npm run build` | نجح |
| Flutter analyze + test | `cd apps/mobile && flutter analyze && flutter test` | نجح |
| Flutter iOS | `flutter build ios --no-codesign` | نجح |
| Flutter Android APK | `flutter build apk --debug` | يحتاج شبكة Maven (قد يفشل بدون اتصال repo.maven.apache.org) |
| Docker Compose | `docker compose up --build` | Docker غير مثبت هنا — استخدم PostgreSQL/Redis المحليين |

بعد `docker compose up` تحقق من:

- `GET http://localhost:3000/health` → 200
- Swagger: http://localhost:3000/api/docs
- Admin: http://localhost:3001

## المرحلة 2 (مؤجّلة)

- Bunny Stream للفيديو
- Cloudflare R2 للصور السحابية
- Meilisearch
- بوابات Zain Cash / Qi
- دردشة Socket.io
- سوق التزيين
- إعداد Firebase للإنتاج
