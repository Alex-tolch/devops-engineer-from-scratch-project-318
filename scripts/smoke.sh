#!/usr/bin/env bash
# Post-deploy smoke checks (app API, Prometheus targets, Grafana, optional Loki).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${ROOT}/terraform"

if [[ -z "${APP_HOST:-}" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
  APP_HOST="$(terraform -chdir="$TERRAFORM_DIR" output -raw droplet_ip 2>/dev/null || true)"
fi
if [[ -z "${MONITORING_HOST:-}" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
  MONITORING_HOST="$(terraform -chdir="$TERRAFORM_DIR" output -raw monitoring_ip 2>/dev/null || true)"
fi

APP_HOST="${APP_HOST:?Set APP_HOST or run terraform apply}"
MONITORING_HOST="${MONITORING_HOST:?Set MONITORING_HOST or run terraform apply}"
METRICS_PASS="${METRICS_PASS:-}"

fail=0
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*"; fail=1; }

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://${APP_HOST}:8080/api/bulletins?page=1&perPage=1" || echo 000)"
[[ "$code" == "200" ]] && ok "app API HTTP $code" || bad "app API HTTP $code (expected 200)"

if [[ -n "$METRICS_PASS" ]]; then
  mcode="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 -u "metrics:${METRICS_PASS}" "http://${APP_HOST}:9090/actuator/health" || echo 000)"
  [[ "$mcode" == "200" ]] && ok "actuator via nginx HTTP $mcode" || bad "actuator via nginx HTTP $mcode"
else
  echo "SKIP metrics actuator (set METRICS_PASS)"
fi

prom="$(curl -sS --max-time 15 "http://${MONITORING_HOST}:9090/api/v1/query?query=up" || true)"
echo "$prom" | grep -q '"value":\["1"\]' && ok "prometheus up query" || bad "prometheus up query"

gcode="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://${MONITORING_HOST}:3000/api/health" || echo 000)"
[[ "$gcode" == "200" ]] && ok "grafana health HTTP $gcode" || bad "grafana health HTTP $gcode"

if command -v python3 >/dev/null && [[ -n "$METRICS_PASS" ]] && [[ -f "${ROOT}/scripts/loki_smoke_test.py" ]]; then
  if APP_HOST="$APP_HOST" MONITORING_HOST="$MONITORING_HOST" METRICS_PASS="$METRICS_PASS" python3 "${ROOT}/scripts/loki_smoke_test.py"; then
    ok "loki e2e smoke"
  else
    bad "loki e2e smoke"
  fi
else
  echo "SKIP loki e2e (python3 + METRICS_PASS)"
fi

exit "$fail"
