#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="/Users/carlos/Development/Leetcode Auto Answer Uploader"

cd "$PROJECT_ROOT"

exec mix run -e "LeetCodeSync.CLI.main(System.argv())" -- "$@"
