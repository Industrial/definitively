#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ ! -f run.log ]]; then
  echo "run.log missing" >&2
  exit 1
fi

if ! grep -q '^metric_value:' run.log; then
  echo "metric_value not found in run.log" >&2
  exit 1
fi

grep '^metric_value:\|^peak_mem_mb:' run.log
