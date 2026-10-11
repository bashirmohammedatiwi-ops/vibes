# تشغيل المكالمات الصوتية بعنوان IP (بدون دومين) — VIBES

> تاريخ آخر تحقق عملي: 2026-10-09 — كل اختبار في هذا الملف نُفّذ فعلياً على السيرفر.

## الحالة الحالية

| المكوّن | القيمة |
|---------|--------|
| سيرفر الإشارة | `ws://187.127.88.146:6002` |
| TURN/UDP | `187.127.88.146:3478` (يعمل — مُتحقق ببروتوكول STUN) |
| نطاق ترحيل TURN | UDP 30000-40000 (شبكة المضيف — لا docker-proxy) |
| ترحيل ICE | `turn:187.127.88.146:3478?transport=udp` يُعلن تلقائياً مع كل مكالمة |
| LiveKit | v1.9.4، `network_mode: host`، healthcheck كل 30s |
| التوكن | يصدره API من `.env` (LIVEKIT_*) — صلاحية 10 دقائق، roomJoin فقط |
| Flutter | `livekit_client` 2.13.0 — يستقبل `url`+`token` من API، **صفر IP ثابت** |

## كيف تعمل المكالمة الآن

1. التطبيق → `POST /api/calls` → يستلم `{ url, token, callId, ... }`
2. التطبيق → `Room.connect(ws://187.127.88.146:6002, token)`
3. LiveKit يرجع `iceServers` تشمل `turn:...:3478?transport=udp` (مُتحقق بمراقبة WebSocket فعلية)
4. الصوت WebRTC/DTLS (مشفّر دائماً) — التشفير المفقود هو الإشارة فقط (ws://)

## الأمان في هذه المرحلة

- **غير مشفّر:** رسائل الإشارة (ws://) — تتضمن توكن الجلسة وبيانات الغرفة
- **مشفّر دائماً:** الصوت نفسه (SRTP/DTLS) مهما كانت الإشارة
- مفاتيح قوية على السيرفر (سر 64 حرفاً) — ليست في Git
- توكنات المستخدمين: صلاحيات محدودة `roomJoin` — **فشل عملي مُتحقق** لمحاولة إدارة غرف بتوكن مستخدم (`permissions denied`)
- الغرف تُحذف تلقائياً عند الفراغ — **مُتحقق عملياً** (غرفة اختبار اختفت بعد مهلتها)
- Android: cleartext محصور بعنوان IP واحد عبر `network_security_config.xml` — ليس على مستوى التطبيق
- iOS: `NSAllowsArbitraryLoads` مؤقتاً (ATS لا يدعم استثناء نطاق لعناوين IP) — موثق للإزالة عند الانتقال لـ wss

## الانتقال المستقبلي إلى الدومين (wss) — 15 دقيقة

**لا يتطلب أي تعديل على Flutter.** كامل المنطق ديناميكي من الـ API.

### الخطوات

1. وجّه A record نطاقك (مثل `rtc.example.com`) → `187.127.88.146`
2. أصدر شهادة SSL وأوقف nginx المشترك مؤقتاً أثناء standalone:
   ```bash
   # على السيرفر
   ufw allow 5349/tcp 2>/dev/null || true
   docker compose -p infra stop   # مؤقتاً — يحرر 80/443
   certbot certonly --standalone -d rtc.example.com
   docker compose -p infra start
   ```
3. ضع الشهادة:
   ```bash
   cp /etc/letsencrypt/live/rtc.example.com/fullchain.pem docker/nginx/certs/
   cp /etc/letsencrypt/live/rtc.example.com/privkey.pem  docker/nginx/certs/
   chmod 644 docker/nginx/certs/*.pem
   ```
4. **`.env`** (هذا كل التغيير للاتصال):
   ```env
   LIVEKIT_URL=wss://rtc.example.com:6002
   ```
5. **TURN/TLS** — `docker/livekit.prod.yaml` فعّل المقاطع المعلقة:
   ```yaml
   turn:
     enabled: true
     udp_port: 3478
     domain: rtc.example.com
     tls_port: 5349
     cert_file: /etc/livekit/certs/fullchain.pem
     key_file: /etc/livekit/certs/privkey.pem
   ```
6. **wss عبر بوابة TLS** — في `docker-compose.prod.yml` خدمة nginx:
   أضف منفذ `6002:6002` واستخدم `docker/nginx/nginx-tls.conf` (جاهز)، أو
   مرّر الإشارة عبر nginx المشترك `infra-nginx-1` (أضف server block للنطاق
   مع proxy WebSocket إلى `187.127.88.146:6002`).
7. أعد التشغيل والتحقق:
   ```bash
   docker compose -f docker-compose.prod.yml up -d livekit
   docker logs vibes-livekit | grep -i turn   # يجب أن يظهر portTLS: 5349
   ```
8. **إزالة استثناءات المرحلة الحالية:**
   - Android: احذف سطر `android:networkSecurityConfig` من AndroidManifest + الملف `res/xml/network_security_config.xml`
   - iOS: استبدل ATS dict بـ `<dict><key>NSAllowsLocalNetworking</key><true/></dict>`
   - حدّث `api_constants.dart` أو استخدم `--dart-define=API_URL=https://...`

### ما يبقى كما هو

- TURN/UDP 3478 + relay 30000-40000 (يُبقى كطبقة سقوط إضافية)
- منطق المكالمات كله في Flutter (لا لمسة)
- توكنات API ومنطق الصلاحيات

## المنافذ المستخدمة فعلياً (مُتحقق بـ ss/ufw)

| المنفذ | البروتوكول | الغرض |
|--------|------------|-------|
| 6001/tcp | HTTP | الموقع + API (nginx) |
| 6002/tcp | WS | إشارة LiveKit |
| 6003/tcp | TCP | احتياط WebRTC TCP |
| 6004-6033/udp | UDP | ICE host/srflx candidates |
| 3478/udp | UDP | TURN |
| 30000-40000/udp | UDP | TURN relay (تخصيص ديناميكي) |
| 5349/tcp | TCP | (مستقبلي) TURN/TLS — مغلق حالياً |

## فحص صحة سريع (روتيني)

```bash
# على السيرفر
docker ps --filter name=vibes --format '{{.Names}}: {{.Status}}'
docker logs vibes-livekit --since 5m | grep -iE 'error|turn'
curl -s http://localhost:6001/health   # → 200

# من الخارج
curl -s http://187.127.88.146:6001/health
python3 -c "import socket,struct,os; s=socket.socket(2,2); s.settimeout(5); s.sendto(struct.pack('!HHI',1,0,0x2112A442)+os.urandom(12),('187.127.88.146',3478)); print('TURN OK' if struct.unpack('!H',s.recvfrom(1024)[0][:2])[0]==0x0101 else 'FAIL')"
```

## استكشاف الأخطاء

| العرَض | السبب المحتمل | الحل |
|--------|---------------|------|
| `تعذّر الوصول لخادم المكالمات` | جدار حماية/شبكة مقيدة | الهاتف ينتقل تلقائياً لـ TURN عبر 3478 |
| `انتهت صلاحية المكالمة` | مرّت 10 دقائق على التوكن | أعد بدء المكالمة (API يصدر توكناً جديداً) |
| صوت يقطع | RTT عالٍ/فقدان حزم | راقب `CallLine` في الواجهة — 2/3 bars تحذير |
| الحاوية restart | راجع `docker logs vibes-livekit` | healthcheck يعيدها تلقائياً |
