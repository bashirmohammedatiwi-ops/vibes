#!/usr/bin/env bash
# نشر API + Admin من الماك إلى سيرفر VIBES ثم إعادة البناء.
# الاستخدام من جذر المشروع:  bash scripts/deploy-server.sh
# خيارات:  bash scripts/deploy-server.sh --api-only | --admin-only | --migrate
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vibes_vps}"
SERVER="${SERVER:-root@187.127.88.146}"
REMOTE_DIR="${REMOTE_DIR:-/root/vibes}"
COMPOSE="${COMPOSE:-docker-compose.prod.yml}"
RSH=(ssh -i "$SSH_KEY" -o BatchMode=yes)
RSYNC_E="ssh -i $SSH_KEY -o BatchMode=yes"

DO_API=1
DO_ADMIN=1
DO_MIGRATE=0
for arg in "$@"; do
  case "$arg" in
    --api-only) DO_ADMIN=0 ;;
    --admin-only) DO_API=0 ;;
    --migrate) DO_MIGRATE=1 ;;
  esac
done

if [[ ! -f "$SSH_KEY" ]]; then
  echo "مفتاح SSH غير موجود: $SSH_KEY" >&2
  exit 1
fi

echo "→ السيرفر: $SERVER  المسار: $REMOTE_DIR"

if [[ "$DO_API" == 1 ]]; then
  echo "→ مزامنة apps/api/src"
  rsync -az --delete -e "$RSYNC_E" \
    --exclude node_modules --exclude dist --exclude '.env' --exclude 'uploads' \
    "$ROOT/apps/api/src/" "$SERVER:$REMOTE_DIR/apps/api/src/"

  echo "→ مزامنة apps/api/prisma"
  rsync -az -e "$RSYNC_E" \
    "$ROOT/apps/api/prisma/" "$SERVER:$REMOTE_DIR/apps/api/prisma/"
fi

if [[ "$DO_ADMIN" == 1 ]]; then
  echo "→ مزامنة apps/admin/src"
  rsync -az -e "$RSYNC_E" \
    --exclude node_modules --exclude .next \
    "$ROOT/apps/admin/src/" "$SERVER:$REMOTE_DIR/apps/admin/src/"
fi

SERVICES=()
[[ "$DO_API" == 1 ]] && SERVICES+=(api)
[[ "$DO_ADMIN" == 1 ]] && SERVICES+=(admin)

echo "→ docker compose up --build ${SERVICES[*]}"
"${RSH[@]}" "$SERVER" \
  "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE' up -d --build --force-recreate ${SERVICES[*]}"

if [[ "$DO_MIGRATE" == 1 ]] || [[ "$DO_API" == 1 ]]; then
  echo "→ prisma migrate deploy"
  "${RSH[@]}" "$SERVER" \
    "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE' exec -T api npx prisma migrate deploy" || true
fi

echo "→ فحص الصحة"
sleep 5
code="$(curl -s -o /dev/null -w '%{http_code}' "http://187.127.88.146:6001/health" || echo fail)"
echo "health HTTP $code"
"${RSH[@]}" "$SERVER" "docker compose -f '$REMOTE_DIR/$COMPOSE' ps api admin | cat"
echo "✓ انتهى النشر"
