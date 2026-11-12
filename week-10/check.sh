#!/usr/bin/env bash
set -u

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
failed=0

ok()  { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failed=1; }

q() {
  printf '%s\n' "$1" |
    kubectl exec -i deploy/db -- sh -c \
      'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA' 2>/dev/null
}

if command -v k6 >/dev/null 2>&1; then
  ok "k6 is installed"
else
  bad "k6 is not installed"
fi

preload="$(q 'SHOW shared_preload_libraries' || true)"
ext="$(q "SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_statements'" || true)"
if printf '%s\n' "$preload" | grep -q pg_stat_statements && [ "$ext" = "1" ]; then
  ok "pg_stat_statements is loaded and created"
else
  bad "pg_stat_statements is not set up"
fi

idx="$(q "SELECT count(*) FROM pg_indexes WHERE indexname = 'idx_tickets_status_created'" || true)"
if [ "$idx" = "1" ]; then
  ok "the index idx_tickets_status_created exists"
else
  bad "the status index does not exist"
fi

ip="$(kubectl get service web -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
page="$(curl -fsS -m 30 "http://${ip}:8080/" 2>/dev/null || true)"
rows="$(printf '%s' "$page" | grep -c '<tr class="status-' || true)"
if [ -n "$page" ] && [ "$rows" -le 50 ]; then
  ok "the live page shows $rows tickets (at most 50)"
else
  bad "the live page is not bounded, or did not answer"
fi

live_cpu="$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)"
live_image="$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

if [ "$live_cpu" = "500m" ] && grep -q 'cpu    = "500m"' "$ROOT/week-5/web.tf"; then
  ok "the web CPU limit is 500m in the cluster and in week-5/web.tf"
else
  bad "the web CPU limit should be 500m in the cluster and file"
fi

if [ "${live_image##*:}" = "v2" ] && grep -q 'week-4-web:v2' "$ROOT/week-5/web.tf"; then
  ok "web runs the v2 image, in the cluster and in week-5/web.tf"
else
  bad "web should run the v2 image in the cluster and file"
fi

( cd "$ROOT/week-5" && tofu plan -input=false -lock=false -detailed-exitcode >/dev/null 2>&1 )
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "tofu plan finds no drift"
elif [ "$rc" -eq 2 ]; then
  bad "tofu plan shows pending changes"
else
  bad "tofu plan could not run (exit code $rc)"
fi

if [ -f "$ROOT/.github/workflows/load-test.yml" ] && grep -q 'p(95)<500' "$HERE/smoke-test.js"; then
  ok "the load-test workflow and p95 threshold exist"
else
  bad "the workflow or p95 threshold is missing"
fi

p95="$("$HERE/k6-stat.sh" restored p95 2>/dev/null || true)"
if [ -n "$p95" ] && [ "$p95" -lt 500 ]; then
  ok "the restored ramped test had a p95 of $p95 ms"
else
  bad "no saved restored ramped test under 500 ms"
fi

if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
