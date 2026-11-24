#!/bin/sh
set -eu
PROJECT="hw3check$(date +%s)$$"
PORT="${CHECK_PORT:-18080}"
N="${CHECK_N:-3}"
BACKUP="${BACKUP_FILE:-$(pwd)/redis-backup.tar}"
stage=setup
cleanup() { status=$?; [ "$status" -eq 0 ] || echo "FAILED at: $stage" >&2; docker compose -p "$PROJECT" down -v --remove-orphans >/dev/null 2>&1 || true; exit "$status"; }
trap cleanup EXIT INT TERM
wait_ready() { i=0; while [ "$i" -lt 60 ]; do curl --max-time 2 -fsS "http://127.0.0.1:$PORT/readyz" >/dev/null 2>&1 && return 0; i=$((i+1)); sleep 1; done; return 1; }
count() { curl --max-time 3 -fsS "http://127.0.0.1:$PORT/" | sed -n 's/.*"count":[[:space:]]*\([0-9][0-9]*\).*/\1/p'; }
post() { curl --max-time 3 -fsS -X POST "http://127.0.0.1:$PORT/increment" | sed -n 's/.*"count":[[:space:]]*\([0-9][0-9]*\).*/\1/p'; }
stage='start clean project'
HOST_PORT="$PORT" docker compose -p "$PROJECT" up -d --build
wait_ready || { echo 'app did not become ready'; exit 1; }
[ "$(count)" = 0 ] || { echo 'initial count is not zero'; exit 1; }
stage='increment counter'
i=0; while [ "$i" -lt "$N" ]; do i=$((i+1)); [ "$(post)" = "$i" ] || exit 1; done
echo "counter after $N increments: $(count)"
stage='restart full project'
docker compose -p "$PROJECT" down
HOST_PORT="$PORT" docker compose -p "$PROJECT" up -d
wait_ready || exit 1; [ "$(count)" = "$N" ] || exit 1
echo "counter after down/up: $(count)"
stage='recreate app'
HOST_PORT="$PORT" docker compose -p "$PROJECT" up -d --force-recreate app
wait_ready || exit 1; [ "$(count)" = "$N" ] || exit 1
echo "counter retained after app recreation: $(count)"
stage='stop redis checks'
docker compose -p "$PROJECT" stop redis >/dev/null
health=$(curl --max-time 8 -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/healthz")
ready=$(curl --max-time 8 -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/readyz")
increment=$(curl --max-time 8 -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/increment")
echo "redis stopped responses: healthz=$health readyz=$ready increment=$increment"
[ "$health" = 200 ] && [ "$ready" = 503 ] && [ "$increment" = 503 ] || { echo "unexpected codes: $health $ready $increment"; exit 1; }
echo "redis stopped: healthz=$health readyz=$ready increment=$increment"
stage='restart redis'
docker compose -p "$PROJECT" start redis >/dev/null
wait_ready || exit 1; [ "$(count)" = "$N" ] || exit 1; [ "$(post)" = "$((N+1))" ] || exit 1
echo "redis recovered without app restart: count=$(count)"
stage='backup and check archive'
docker compose -p "$PROJECT" stop app redis >/dev/null
MSYS_NO_PATHCONV=1 docker run --rm -v "${PROJECT}_redis_data:/source:ro" alpine:3.20 tar cpf - -C /source . > "$BACKUP"
test -s "$BACKUP"
MSYS_NO_PATHCONV=1 docker run --rm -i alpine:3.20 tar tf - < "$BACKUP" >/dev/null
echo "backup created and archive checked: $BACKUP"
stage=complete; echo PASS
