#!/usr/bin/env bash
# نشر إصلاح «Unauthorized» + الحجوزات + الريلز على سيرفر VIBES.
# شغّله من جذر المشروع:  bash scripts/deploy-api-session-fix.sh
# يلمس حاوية vibes-api فقط (السيرفر يستضيف مشاريع أخرى).
set -euo pipefail

SERVER="${SERVER:-root@187.127.88.146}"
KEY="${KEY:-$HOME/.ssh/vibes_vps}"
REMOTE_DIR="${REMOTE_DIR:-/root/vibes}"
COMPOSE="${COMPOSE:-docker-compose.prod.yml}"
SSH=(ssh -i "$KEY" -o BatchMode=yes "$SERVER")

FILES=(
  apps/api/src/modules/auth/auth.service.ts
  apps/api/src/modules/auth/auth.module.ts
  apps/api/src/modules/bookings/bookings.controller.ts
  apps/api/src/modules/bookings/bookings.service.ts
  apps/api/src/modules/marketplace/commerce.service.ts
  apps/api/src/modules/reels/reels.controller.ts
  apps/api/src/media/media-pipeline.service.ts
)

TS=$(date +%Y%m%d-%H%M%S)
echo "→ نسخة احتياطية: /root/vibes-api-backup-$TS.tgz"
"${SSH[@]}" "cd '$REMOTE_DIR' && tar czf /root/vibes-api-backup-$TS.tgz ${FILES[*]} .env apps/api/.env 2>/dev/null || true"

echo "→ رفع الملفات"
rsync -az --relative -e "ssh -i $KEY -o BatchMode=yes" "${FILES[@]}" "$SERVER:$REMOTE_DIR/"

echo "→ مدة الجلسة: الوصول 1h والتحديث 90d"
"${SSH[@]}" "cd '$REMOTE_DIR' && for e in .env apps/api/.env; do [ -f \$e ] && sed -i 's/^JWT_ACCESS_EXPIRES_IN=15m\$/JWT_ACCESS_EXPIRES_IN=1h/; s/^JWT_REFRESH_EXPIRES_IN=30d\$/JWT_REFRESH_EXPIRES_IN=90d/' \$e; done; grep -hE 'JWT_(ACCESS|REFRESH)_EXPIRES' .env apps/api/.env || true"

echo "→ إعادة بناء وتشغيل حاوية الـ API فقط"
"${SSH[@]}" "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE' up -d --build api"

echo "→ فحص الصحة"
sleep 15
"${SSH[@]}" "docker ps --filter name=vibes-api --format '{{.Names}} {{.Status}}'; docker logs --tail=30 vibes-api"
echo "✓ تم. للتراجع: فك النسخة الاحتياطية في $REMOTE_DIR ثم أعد بناء api."
