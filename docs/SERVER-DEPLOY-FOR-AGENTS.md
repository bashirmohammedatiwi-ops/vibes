# نشر السيرفر + GitHub — تعليمات للوكلاء (Claude / Cursor)

استخدم هذا الملف كلما طلب المستخدم «حدّث السيرفر» أو بعد تعديلات جوهرية على الكود.

**بعد كل عمل مكتمل: (1) commit + push إلى GitHub، ثم (2) نشر السيرفر إن لزم.** لا تترك أيّاً منهما للمستخدم.

## GitHub (إلزامي)

| البند | القيمة |
|---|---|
| Remote | `origin` → `https://github.com/bashirmohammedatiwi-ops/vibes.git` |
| الفرع الافتراضي | `main` |

### ماذا تفعل بعد انتهاء التعديلات

```bash
# من جذر المشروع على الماك
git status
git add <الملفات ذات الصلة>   # لا تضف .env أو أسرار
git commit -m "$(cat <<'EOF'
رسالة مختصرة توضح السبب.

EOF
)"
git push -u origin HEAD
```

قواعد Git للوكيل:

1. **ادفع إلى GitHub دائماً** بعد commit ناجح للعمل المكتمل — المستخدم فوّض ذلك لهذا المشروع.
2. لا ترفع أسراراً (`.env`, مفاتيح, credentials).
3. لا تستخدم `--force` على `main` إلا بطلب صريح.
4. إن فشل الـ push بسبب تعارض: `git pull --rebase origin main` ثم أعد `git push` (بدون force).
5. نشر السيرفر (`rsync`/Docker) **لا يغني** عن الرفع إلى GitHub — الاثنان مطلوبان.

## الوصول إلى السيرفر

| البند | القيمة |
|---|---|
| المضيف | `187.127.88.146` |
| المستخدم | `root` |
| مفتاح SSH | `~/.ssh/vibes_vps` (BatchMode، بدون كلمة مرور) |
| مسار المشروع على السيرفر | `/root/vibes` |
| Compose | `docker-compose.prod.yml` |
| API العام | `http://187.127.88.146:6001` |
| Health | `http://187.127.88.146:6001/health` |
| Admin | `http://187.127.88.146:6001/admin/` |

### أمر SSH الأساسي

```bash
ssh -i ~/.ssh/vibes_vps -o BatchMode=yes root@187.127.88.146 '…'
```

لا تعتمد على `git pull` على السيرفر كمصدر وحيد للحقيقة: الماك والسيرفر غالباً متباعدان. **زامن الملفات من الماك → السيرفر ثم أعد البناء.**

## التحديث القياسي (API + Admin)

من جذر المشروع على الماك:

```bash
# 1) مزامنة كود الـ API
rsync -az --delete -e 'ssh -i ~/.ssh/vibes_vps -o BatchMode=yes' \
  --exclude node_modules --exclude dist --exclude '.env' --exclude 'uploads' \
  /Users/cloud/Desktop/project-2/apps/api/src/ \
  root@187.127.88.146:/root/vibes/apps/api/src/

rsync -az -e 'ssh -i ~/.ssh/vibes_vps -o BatchMode=yes' \
  /Users/cloud/Desktop/project-2/apps/api/prisma/ \
  root@187.127.88.146:/root/vibes/apps/api/prisma/

# 2) مزامنة لوحة الإدارة (إن لزم)
rsync -az -e 'ssh -i ~/.ssh/vibes_vps -o BatchMode=yes' \
  --exclude node_modules --exclude .next \
  /Users/cloud/Desktop/project-2/apps/admin/src/ \
  root@187.127.88.146:/root/vibes/apps/admin/src/

# 3) إعادة البناء والتشغيل
ssh -i ~/.ssh/vibes_vps -o BatchMode=yes root@187.127.88.146 \
  'cd /root/vibes && docker compose -f docker-compose.prod.yml up -d --build --force-recreate api admin'

# 4) migrations إن وُجدت جديدة
ssh -i ~/.ssh/vibes_vps -o BatchMode=yes root@187.127.88.146 \
  'cd /root/vibes && docker compose -f docker-compose.prod.yml exec -T api npx prisma migrate deploy'

# 5) تحقق
curl -s -o /dev/null -w "%{http_code}\n" http://187.127.88.146:6001/health
```

أو اختصاراً من جذر المشروع:

```bash
bash scripts/deploy-server.sh
```

## حاويات مهمة

| اسم الحاوية | الدور |
|---|---|
| `vibes-api` | Nest API |
| `vibes-admin` | Next admin |
| `vibes-postgres` | قاعدة البيانات |
| `vibes-redis` | كاش / OTP |
| `vibes-livekit` | مكالمات |

بعد تغييرات تؤثر على قوائم/بانرات/أماكن، امسح كاش Redis إن لزم:

```bash
ssh -i ~/.ssh/vibes_vps -o BatchMode=yes root@187.127.88.146 \
  'docker compose -f /root/vibes/docker-compose.prod.yml exec -T redis redis-cli FLUSHDB'
```

## تشغيل سكربت Prisma داخل الحاوية

```bash
# انسخ الملف ثم نفّذه من /app (حيث node_modules)
docker compose -f /root/vibes/docker-compose.prod.yml cp /tmp/script.js api:/app/script.js
docker compose -f /root/vibes/docker-compose.prod.yml exec -T api node /app/script.js
```

لا تشغّل `require('@prisma/client')` من `/tmp` داخل الحاوية — المسار الصحيح `/app`.

## مصادقة إدارية للاختبار / الرفع

- هاتف الأدمن: `9647700000000`
- OTP للتطوير: أرسل OTP ثم تحقق بـ `123456` (وضع development)

```bash
curl -s -X POST http://187.127.88.146:6001/api/auth/otp/send \
  -H 'Content-Type: application/json' -d '{"phone":"9647700000000"}'
# ثم
curl -s -X POST http://187.127.88.146:6001/api/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"phone":"9647700000000","code":"123456"}'
```

رفع وسائط: `POST /api/media/upload` مع `Authorization: Bearer <token>` وحقل `file` (و`propertyId` اختياري).

## ما لا يُنشر عبر Docker

- **تطبيق الموظفين** `apps/staff`: يُبنى على الماك (`flutter build apk`) ويُثبَّت بـ `adb` على الجهاز. لا يوجد مجلد staff على السيرفر.
- **تطبيق الزبائن** `apps/mobile`: نفس الفكرة — APK محلي، ليس على السيرفر.

## قواعد للوكيل

1. بعد انتهاء العمل: **commit + `git push origin`** إلى GitHub أولاً.
2. بعد أي تعديل جوهري على API/Admin: زامن + أعد بناء + تحقق من `/health`.
3. لا تفترض أن Git على السيرفر محدّث؛ `rsync` من الماك هو مصدر نشر السيرفر.
4. استخدم دائماً `-i ~/.ssh/vibes_vps -o BatchMode=yes`.
5. المسار هو `/root/vibes` وليس `/opt/vibes`.
6. إن فشل البناء: `docker logs vibes-api --tail 80`.
7. لا تلمس `.env` الإنتاج ولا ترفعه إلى GitHub إلا بطلب صريح من المستخدم.
