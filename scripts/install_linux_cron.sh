#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRON_TEMPLATE="$PROJECT_ROOT/priv/automation/linux/leetcode-sync.cron"
TMP_CRON="$(mktemp)"

sed "s#__PROJECT_ROOT__#$PROJECT_ROOT#g" "$CRON_TEMPLATE" > "$TMP_CRON"

{
  crontab -l 2>/dev/null | grep -v "leetcode-sync" || true
  cat "$TMP_CRON"
} | crontab -

rm -f "$TMP_CRON"
echo "Installed cron entries for leetcode-sync"
