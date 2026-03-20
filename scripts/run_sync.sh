#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="/Users/carlos/Development/Leetcode Auto Answer Uploader"

cd "$PROJECT_ROOT"

if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

exec mix run -e "LeetCodeSync.CLI.main()"
