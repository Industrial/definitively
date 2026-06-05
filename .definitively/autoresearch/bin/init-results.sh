#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ ! -f results.tsv ]]; then
  printf '%s\n' $'commit\tmetric_value\tmemory_gb\tstatus\tdescription' > results.tsv
fi

echo "results.tsv initialized"
