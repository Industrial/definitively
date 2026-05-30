#!/usr/bin/env bash
# Run cargo (or a cargo wrapper command) only when the workspace has members.
set -euo pipefail

members="$(
  cargo metadata --format-version 1 --no-deps 2>/dev/null \
    | jq -r '.workspace_members | length' 2>/dev/null \
    || echo 0
)"

if [[ "${members:-0}" -eq 0 ]]; then
    echo "Skipping: Cargo workspace has no members (${members:-0})"
    exit 0
fi

exec "$@"
