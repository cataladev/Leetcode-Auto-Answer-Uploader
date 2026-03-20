#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="/Users/carlos/Development/Leetcode Auto Answer Uploader"
PLIST_SOURCE="$PROJECT_ROOT/priv/automation/macos/dev.cataladev.leetcode-sync.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/dev.cataladev.leetcode-sync.plist"
LABEL="dev.cataladev.leetcode-sync"
USER_DOMAIN="gui/$(id -u)"

mkdir -p "$HOME/Library/LaunchAgents" "$PROJECT_ROOT/logs"
cp "$PLIST_SOURCE" "$PLIST_TARGET"

launchctl bootout "$USER_DOMAIN" "$PLIST_TARGET" >/dev/null 2>&1 || true
launchctl bootstrap "$USER_DOMAIN" "$PLIST_TARGET"
launchctl enable "$USER_DOMAIN/$LABEL"
launchctl kickstart -k "$USER_DOMAIN/$LABEL"

echo "Installed and started $LABEL"
