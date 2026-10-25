#!/usr/bin/env bash
# نقل VIBES إلى الدومين vibesiraq.com — الخطوات المتبقية على السيرفر.
# (الشهادة + nginx المشترك + HTTPS مُنجزة مسبقاً.)
#
#   bash scripts/switch-to-domain.sh
#
# ما يفعله (مع نسخ احتياطية قبل أي تعديل في /root/backups):
#   1. .env: APP_URL / ADMIN_URL / MEDIA_PUBLIC_URL / PUBLIC_WEB_URL → https://vibesiraq.com
#      LIVEKIT_URL → wss://vibesiraq.com — CORS يبقي عنوان IP القديم للتوافق.
#   2. قاعدة البيانات: روابط الصور المحفوظة بـ http://187.127.88.146:6001 → https://vibesiraq.com
#   3. مسح كاش Redis للقوائم.
#   4. تجديد تلقائي للشهادة (cron أسبوعي) — خدمة certbot في المشروع المشترك متوقفة.
#   5. إعادة بناء API ولوحة التحكم (تستخدم APP_URL وقت البناء).
set -euo pipefail

HOST="root@187.127.88.146"
KEY="$HOME/.ssh/vibes_vps"
OLD="http://187.127.88.146:6001"
NEW="https://vibesiraq.com"

ssh -i "$KEY" "$HOST" bash -s <<EOF
set -euo pipefail
TS=\$(date +%Y%m%d-%H%M%S)
mkdir -p /root/backups
cd /root/vibes

echo "→ 1) .env (نسخة: /root/backups/vibes.env.\$TS)"
cp .env /root/backups/vibes.env.\$TS
sed -i -E \
  -e "s#^APP_URL=.*#APP_URL=$NEW#" \
  -e "s#^ADMIN_URL=.*#ADMIN_URL=$NEW#" \
  -e "s#^MEDIA_PUBLIC_URL=.*#MEDIA_PUBLIC_URL=$NEW/media#" \
  -e "s#^PUBLIC_WEB_URL=.*#PUBLIC_WEB_URL=$NEW#" \
  -e "s#^LIVEKIT_URL=.*#LIVEKIT_URL=wss://vibesiraq.com#" \
  -e "s#^CORS_ORIGINS=.*#CORS_ORIGINS=$NEW,https://www.vibesiraq.com,$OLD#" \
  .env
grep -E "^(APP_URL|ADMIN_URL|MEDIA_PUBLIC_URL|PUBLIC_WEB_URL|LIVEKIT_URL|CORS_ORIGINS)=" .env

echo "→ 2) قاعدة البيانات (نسخة: /root/backups/vibes-urls.\$TS.sql)"
PGU=\$(docker exec vibes-postgres printenv POSTGRES_USER)
PGD=\$(docker exec vibes-postgres printenv POSTGRES_DB)
docker exec vibes-postgres pg_dump -U "\$PGU" -d "\$PGD" --data-only \
  -t media -t banners -t provinces -t messages > /root/backups/vibes-urls.\$TS.sql
docker exec -i vibes-postgres psql -U "\$PGU" -d "\$PGD" -v ON_ERROR_STOP=1 <<SQL
BEGIN;
UPDATE media     SET url       = replace(url,       '$OLD', '$NEW') WHERE url       LIKE '$OLD%';
UPDATE banners   SET image_url = replace(image_url, '$OLD', '$NEW') WHERE image_url LIKE '$OLD%';
UPDATE provinces SET image_url = replace(image_url, '$OLD', '$NEW') WHERE image_url LIKE '$OLD%';
UPDATE messages  SET image_url = replace(image_url, '$OLD', '$NEW') WHERE image_url LIKE '$OLD%';
COMMIT;
SQL

echo "→ 3) مسح كاش القوائم"
docker exec vibes-redis sh -c 'redis-cli --scan --pattern "cache:*" | xargs -r redis-cli del' || true

echo "→ 4) تجديد الشهادة تلقائياً"
cat > /etc/cron.d/vibes-certbot <<'CRON'
# تجديد شهادة vibesiraq.com أسبوعياً ثم إعادة تحميل nginx المشترك (بلا انقطاع)
17 4 * * 1 root docker run --rm -v infra_certbot_www:/var/www/certbot -v infra_certbot_certs:/etc/letsencrypt certbot/certbot:latest renew --cert-name vibesiraq.com --webroot -w /var/www/certbot --quiet && docker exec infra-nginx-1 nginx -s reload >/dev/null 2>&1
CRON
chmod 644 /etc/cron.d/vibes-certbot
EOF

echo "→ 5) إعادة بناء API ولوحة التحكم"
bash "$(dirname "$0")/deploy-server.sh"

echo "→ فحص"
curl -s -o /dev/null -w "health %{http_code}\n" "$NEW/health"
curl -s -o /dev/null -w "admin  %{http_code}\n" "$NEW/admin/login"
echo "✓ تم — لوحة التحكم: $NEW/admin"
