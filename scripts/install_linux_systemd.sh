#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$PROJECT_ROOT/logs"

sed "s#__PROJECT_ROOT__#$PROJECT_ROOT#g" "$PROJECT_ROOT/priv/automation/linux/leetcode-sync.service" \
  > "$SYSTEMD_USER_DIR/leetcode-sync.service"

sed "s#__PROJECT_ROOT__#$PROJECT_ROOT#g" "$PROJECT_ROOT/priv/automation/linux/leetcode-sync.timer" \
  > "$SYSTEMD_USER_DIR/leetcode-sync.timer"

systemctl --user daemon-reload
systemctl --user enable leetcode-sync.service
systemctl --user enable --now leetcode-sync.timer
systemctl --user start leetcode-sync.service
echo "Installed leetcode-sync systemd user login service and timer"
