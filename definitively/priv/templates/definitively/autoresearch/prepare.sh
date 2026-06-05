#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)"
SANDBOX="${ROOT}/.definitively/autoresearch"

cd "$SANDBOX"

if ! command -v elixir >/dev/null 2>&1; then
  echo "elixir not found on PATH" >&2
  exit 1
fi

for path in fixtures/problem.exs eval.exs candidate.exs; do
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
done

echo "autoresearch sandbox ready"
