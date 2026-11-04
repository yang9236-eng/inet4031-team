#!/usr/bin/env bash
# Check the database, exporter, backups and backup schedule.
set -u

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

failed=0
ok()  { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failed=1; }

if kubectl exec deploy/db -- sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
  ok "the database is accepting connections"
else
  bad "the database is not accepting connections"
fi

metrics="$(kubectl exec deploy/web -- python -c "import urllib.request; print(urllib.request.urlopen('http://db-exporter:9187/metrics').read().decode())" 2>/dev/null || true)"
if printf '%s\n' "$metrics" | grep -q '^pg_up 1'; then
  ok "the exporter is running and reaches the database (pg_up is 1)"
else
  bad "the exporter does not answer, or cannot reach the database (pg_up is not 1)"
fi

newest="$(ls -1t "$HOME"/backups/db-*.dump 2>/dev/null | head -n 1 || true)"
if [ -z "$newest" ]; then
  bad "there are no backups in ~/backups"
else
  age=$(( $(date +%s) - $(stat -c %Y "$newest") ))
  if [ "$age" -le 900 ]; then
    ok "the newest backup is $age seconds old"
  else
    bad "the newest backup is $age seconds old, which is more than 15 minutes (is cron running?)"
  fi

  if kubectl exec -i deploy/db -- pg_restore --list < "$newest" 2>/dev/null | grep -q ' TABLE DATA '; then
    ok "the newest backup is readable and contains table data"
  else
    bad "the newest backup cannot be read, or contains no table data"
  fi
fi

if crontab -l 2>/dev/null | grep -q 'week-9/backup.sh'; then
  ok "cron has a line for week-9/backup.sh"
else
  bad "cron has no line for week-9/backup.sh"
fi

if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
