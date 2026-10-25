# رفع VIBES على المتاجر — دليل جاهز

## الروابط المطلوبة في المتجرين

| الحقل | الرابط |
|---|---|
| سياسة الخصوصية (Privacy Policy URL) | https://vibesiraq.com/privacy |
| شروط الاستخدام | https://vibesiraq.com/terms |
| رابط حذف الحساب (Google Play → Data safety → Account deletion) | https://vibesiraq.com/delete-account |
| موقع الدعم (Support URL) / Marketing URL | https://vibesiraq.com |

## معرّفات التطبيقات

| | iOS Bundle ID | Android applicationId | الإصدار |
|---|---|---|---|
| تطبيق الزبون (VIBES) | `com.vibesiq.app` | `com.vibes.vibes` | 1.0.0 (6) |
| تطبيق الموظفين | `com.vibesiq.staff` | `iq.vibes.staff` | 2.1.1 (25) |

- Android: ارفع ملف `build/app/outputs/bundle/release/app-release.aab` (موقّع بمفتاح الرفع في `~/vibes-keys`). فعّل **Play App Signing** عند أول رفع.
- iOS: من Xcode → Product → Archive → Distribute App → App Store Connect.

---

## نصوص المتجر — تطبيق الزبون

**الاسم:** VIBES — حجز مزارع وقاعات

**العنوان الفرعي (iOS, 30 حرفاً):** مزارع، قاعات وتزيين في العراق

**الوصف القصير (Google Play, 80 حرفاً):** احجز مزرعتك أو قاعة مناسبتك أو فريق التزيين بسهولة في كل العراق

**الوصف الكامل:**

VIBES أسهل طريقة لحجز أماكن مناسباتك في العراق.

• مزارع للعزائم والجلسات العائلية — ومزارع شتوية ومسابح مغلقة
• قاعات أعراس ومناسبات بكل المحافظات
• فرق تزيين لأعياد الميلاد والخطوبة والأعراس

لماذا VIBES؟
• تقويم واضح يُظهر الأيام المتاحة وسعر كل يوم
• احجز صباحي أو مسائي أو يوم كامل
• صور حقيقية، تقييمات الضيوف، وموقع المكان على الخريطة
• كوبونات خصم وعروض أسعار خاصة
• نديم — مخطّط مناسبات يقترح عليك أنسب الأماكن بأسئلة بسيطة
• محادثة مباشرة مع الدعم وصاحب المكان
• تابع حجوزاتك وارفع إيصال الدفع واحصل على فاتورتك

**الكلمات المفتاحية (iOS):** مزرعة,قاعة,حجز,أعراس,مناسبات,تزيين,عيد ميلاد,خطوبة,بغداد,العراق,مسبح

**الفئة:** Travel (السفر) — أو Lifestyle

**تصنيف العمر:** 4+ (iOS) / Everyone (Play) — لا محتوى حساس.

---

## App Privacy (App Store Connect) — الإجابات

Data used to track you: **لا شيء** (No tracking).

Data linked to you — كلها لغرض **App Functionality** فقط:

| الفئة | النوع |
|---|---|
| Contact Info | Name, Phone Number |
| User Content | Photos or Videos (إيصالات وصور المحادثات)، Emails or Text Messages (رسائل داخل التطبيق)، Other User Content (التقييمات والمنشورات) |
| Identifiers | User ID, Device ID |
| Purchases | Purchase History (الحجوزات) |

ليست مجمّعة: الموقع (يُستخدم على الجهاز فقط ولا يُحفظ)، الصوت (المكالمات مباشرة ولا تُسجَّل)، بيانات بطاقات الدفع.

> هذه الإجابات مطابقة لملف `ios/Runner/PrivacyInfo.xcprivacy`.

## Data safety (Google Play) — الإجابات

- **Does your app collect or share user data?** Yes — collect. **Shared:** No (مزوّدو الخدمة لا يُحسبون مشاركة).
- **Encrypted in transit:** Yes. **Users can request deletion:** Yes (داخل التطبيق + https://vibesiraq.com/delete-account).
- البيانات المجمّعة (كلها Required إلا الصور، والغرض App functionality + Account management):
  - Personal info: Name (اختياري)، Phone number
  - Photos and videos: Photos (اختياري — الإيصالات والمحادثات)
  - Messages: Other in-app messages
  - App activity: Other user-generated content (التقييمات)
  - Financial info: Purchase history (الحجوزات)
  - Device or other IDs
  - Location: Approximate/Precise — **غير مجمّع** (يُستخدم على الجهاز فقط لعرض القريب)
  - Audio: **غير مجمّع** (المكالمات لا تُسجَّل)

## الأذونات وأسبابها

| الإذن | السبب |
|---|---|
| الكاميرا / الصور | تصوير وإرفاق إيصال الدفع وصور التجربة |
| الموقع (أثناء الاستخدام) | عرض الأماكن القريبة |
| الميكروفون | الاتصال بالدعم من داخل التطبيق |

## ملاحظات للمراجع (App Review Notes)

أنشئ حساباً تجريبياً برقم تملكه ورمز من 6 أرقام وضعه في خانة Sign-in information، مع هذا النص:

> VIBES is a booking marketplace for farms, event halls and decoration teams in Iraq. Browsing works without an account. To test booking: sign in with the demo phone number and 6-digit PIN above, open any place, pick an available day on the calendar and tap "احجز الآن". Payment is a manual bank transfer or local payment gateway for a physical service (venue rental), confirmed by our staff — no digital goods are sold. Account deletion: Profile (ملفي) → حذف الحساب.
>
> Owner mode: verified venue owners can switch to an owner portal from Profile → "مالك مزرعة أو قاعة؟" to manage their calendar and booking requests. Owner accounts are linked by our team after verifying ownership (no self sign-up, no payments to us inside the app). Demo owner account: <phone> / <PIN>.

### بوابة المالك داخل تطبيق الزبون

- مسموحة: تطبيق واحد لنوعين من المستخدمين شائع (مثل Airbnb). لا يُباع فيها شيء رقمي، ولا تسجيل ذاتي، ولا رفع وثائق هوية.
- **مهم:** أعطِ المراجع حساب مالك تجريبي مربوطاً بمكان تجريبي (في الملاحظات أعلاه)، وإلا قد يطلب Apple الوصول لهذه الميزة (Guideline 2.1).
- حذف حساب المالك من التطبيق يرسل طلب حذف للدعم فوراً ويُخبره أنه يُنفَّذ خلال 7 أيام (بسبب حجوزات أماكنه) — مقبول لدى Apple ما دام يبدأ من داخل التطبيق وتُوضَّح المدة. نفّذ هذه الطلبات من لوحة التحكم ضمن المدة.

---

## تطبيق الموظفين — تنبيه مهم

تطبيق الموظفين أداة داخلية (لا تسجيل للعامة). Apple ترفض عادةً التطبيقات الداخلية على المتجر العام، لذا:

- **iOS:** اطلب **Unlisted App Distribution** من Apple (https://developer.apple.com/support/unlisted-app-distribution/) — يُرفع عادياً لكن لا يظهر في البحث ويُثبَّت برابط مباشر. أو وزّعه عبر TestFlight.
- **Android:** استخدم مسار **Internal testing** في Google Play (حتى 100 مختبِر) — لا يحتاج مراجعة عامة.
- يطلب التطبيق «تجاهل تحسين البطارية» و«خدمة المقدمة للمكالمات» لاستقبال مكالمات الزبائن؛ في المسار العام يطلب Google تبريراً وفيديو، لذلك المسار الداخلي أنسب.
