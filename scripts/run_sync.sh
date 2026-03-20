#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="/Users/carlos/Development/Leetcode Auto Answer Uploader"

cd "$PROJECT_ROOT"

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

exec mix run -e "LeetCodeSync.CLI.main(System.argv())" -- "$@"
