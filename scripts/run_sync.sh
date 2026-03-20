#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="/Users/carlos/Development/Leetcode Auto Answer Uploader"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

cd "$PROJECT_ROOT"

exec mix run -e "LeetCodeSync.CLI.main(System.argv())" -- "$@"
