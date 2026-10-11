# Nginx — VIBES

## الوضع الحالي للسيرفر (مُحدَّث 2026-10-09)

السيرفر `187.127.88.146` **مشترك** بين عدة مشاريع: المنافذ 80/443 يحجزها nginx
آخر (`infra-nginx-1` لمشروع alhayaa مع certbot خاص به). لذلك:

- موقع VIBES يُخدم على **http://187.127.88.146:6001** (nginx.conf العادي)
- إشارة LiveKit على **ws://187.127.88.146:6002** مباشرة (شبكة المضيف — بدون docker-proxy)
- **TURN مُفعّل**: 3478/udp + نطاق ترحيل 30000-40000/udp مفتوح في UFW
- **wss و TURN/TLS معطّلان مؤقتاً** — يتطلبان دوميناً يشير للسيرفر + شهادة SSL،
  ولا يوجد حالياً دومين VIBES مسجّل (`vibes.iq` بلا سجل A). كل التجهيزات
  جاهزة للتفعيل الفوري عند توفر الدومين (انظر أدناه).

## المسارات (nginx.conf الحالي)

| المسار | الوجهة |
|--------|--------|
| `/api` | NestJS `:3000` |
| `/api/docs` | Swagger |
| `/health` | Health check |
| `/admin` | Next.js admin `:3001` |
| `/media` | ملفات الصور المحلية |

## ترقية المفاتيح (تمت على السيرفر)

المفاتيح الافتراضية `devkey/devsecret...` استُبدلت على السيرفر بمفاتيح قوية
(السر 64 حرفاً — القديم كان 30 حرفاً فقط و LiveKit كان يطبع تحذيراً في كل إقلاع).
على السيرفر: `LIVEKIT_API_KEY=vibesd45c9417` في `.env` + نفس القيمة في
`docker/livekit.prod.yaml`. **لا تحفظ قيم الإنتاج في المستودع.**

## الترقية إلى TLS (wss + TURN/TLS) — عند توفر دومين

ملف `nginx-tls.conf` جاهز لكنه **غير مفعّل** (غير مركّب في compose) لأنه
يتطلب دوميناً وشهادة، ويحجز منافذ قد تتعارض مع البنية المشتركة. خطوات التفعيل:

1. وجّه A record لدومينك (مثل `rtc.your-domain.com`) إلى `187.127.88.146`
2. أصدر شهادة (Certbot أو Cloudflare Origin) وضعها في `docker/nginx/certs/`
   (`fullchain.pem` + `privkey.pem`)
3. في `docker-compose.prod.yml`:
   - nginx: استبدل `nginx.conf` بـ `nginx-tls.conf` وانشر `443:443` و`6002:6002`
     (تأكد أولاً أن 80/443 غير محجوزين — حالياً محجوزان من infra-nginx)
   - عدّل `server_name` في nginx-tls.conf لدومينك
4. في `docker/livekit.prod.yaml`: فعّل مقطع `turn.domain/tls_port/cert_file/key_file`
5. في `.env`: `LIVEKIT_URL=wss://rtc.your-domain.com:6002`
6. فتح المنافذ إن لزم: `5349/tcp`
7. `docker compose -f docker-compose.prod.yml up -d livekit nginx`
8. تحقق: `docker logs vibes-livekit | grep -i turn` — يجب أن ترى
   `Starting TURN server` مع `turn.portTLS: 5349`

### ملاحظات شهادة SSL

**Certbot (Let's Encrypt):** يحتاج المنفذ 80 متاحاً — على هذا السيرفر المشترك
يمكن استخدام `--standalone` بعد إيقاف infra-nginx مؤقتاً، أو webroot عبر مجلد
certbot المشترك الموجود مسبقاً.

**Cloudflare Origin Certificate (مجاني، 15 سنة):** أنشئ شهادة أصل من لوحة
Cloudflare → SSL/TLS → Origin Server، وضعها في `docker/nginx/certs/`.

### ⚠️ تنبيه Cloudflare

وكيل Cloudflare (السحابة البرتقالية) يمرر **HTTP/HTTPS فقط على منافذه القياسية** —
منافذ LiveKit (6002, 5349, 6004-6033) لن تصل للسيرفر عبره. الحل: نطاق فرعي
مخصص (مثل `rtc.vibes.iq`) بحالة **DNS only** (سحابة رمادية) للـ wss و TURN و
WebRTC، وأصدر شهادة منفصلة تشمله:

```bash
sudo certbot certonly --standalone -d vibes.iq -d rtc.vibes.iq
```

ثم اجعل `LIVEKIT_URL=wss://rtc.vibes.iq:6002` و`turn.domain: rtc.vibes.iq`.

## TURN الحالي (بدون TLS)

- **3478/udp** — TURN للأجهزة التي تفشل مع UDP المباشر
- **30000-40000/udp** — منافذ الترحيل (تعمل لأن الحاوية على شبكة المضيف)
- يُعلن LiveKit عن خوادم ICE تلقائياً مع كل مكالمة — **تطبيق Flutter لا يحتاج أي تعديل**
