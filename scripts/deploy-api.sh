#!/usr/bin/env bash
# نشر تحديث الـ API (إدارة الأماكن من تطبيق الموظفين) على السيرفر.
# شغّله من جذر المشروع على جهازك:  bash scripts/deploy-api.sh
set -euo pipefail

# ملاحظة: للنشر الكامل استخدم scripts/deploy-server.sh
# هذا السكربت قديم ومحدود — يوجّه إلى المسار الصحيح.
SERVER="${SERVER:-root@187.127.88.146}"
KEY="${KEY:-$HOME/.ssh/vibes_vps}"
REMOTE_DIR="${REMOTE_DIR:-/root/vibes}"
COMPOSE="${COMPOSE:-docker-compose.prod.yml}"
SSH=(ssh -i "$KEY" -o BatchMode=yes "$SERVER")

FILES=(
  ./apps/api/src/modules/admin/admin.module.ts
  ./apps/api/src/modules/staff/staff.module.ts
  ./apps/api/src/modules/staff/staff.permissions.ts
  ./apps/api/src/modules/staff/staff.service.ts
  ./apps/api/src/modules/staff/staff-properties.controller.ts
  ./apps/api/src/modules/staff/staff-properties.service.ts
)

echo "→ نسخ احتياطي للملفات الحالية على السيرفر"
"${SSH[@]}" "cd '$REMOTE_DIR' && tar czf /tmp/vibes-api-backup-\$(date +%Y%m%d-%H%M%S).tgz apps/api/src/modules/staff apps/api/src/modules/admin/admin.module.ts"

echo "→ رفع الملفات"
rsync -avz --relative -e "ssh -i $KEY -o BatchMode=yes" "${FILES[@]}" "$SERVER:$REMOTE_DIR/"

echo "→ إعادة بناء وتشغيل حاوية الـ API"
"${SSH[@]}" "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE' up -d --build api"

echo "→ فحص الصحة"
sleep 10
"${SSH[@]}" "docker compose -f '$REMOTE_DIR/$COMPOSE' ps api && docker compose -f '$REMOTE_DIR/$COMPOSE' logs --tail=40 api"
echo "✓ تم. جرّب: curl http://187.127.88.146:6001/health"
