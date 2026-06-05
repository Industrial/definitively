#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)"
SANDBOX="${ROOT}/.definitively/autoresearch"

cd "$SANDBOX"

metric_from_log() {
  grep '^metric_value:' run.log | awk '{print $2}'
}

mem_gb_from_log() {
  local mb
  mb="$(grep '^peak_mem_mb:' run.log | awk '{print $2}')"
  if [[ -z "$mb" ]]; then
    echo "0.0"
  else
    awk -v mb="$mb" 'BEGIN { printf "%.1f", mb / 1024 }'
  fi
}

short_commit() {
  git rev-parse --short HEAD 2>/dev/null || echo "0000000"
}
