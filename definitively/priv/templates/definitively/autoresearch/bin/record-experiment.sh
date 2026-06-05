#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

desc_file="experiment.desc"
if [[ -f "$desc_file" ]]; then
  description="$(tr '\n' ' ' < "$desc_file" | sed 's/[[:space:]]*$//')"
else
  description="experiment"
fi

commit="$(short_commit)"

if [[ ! -f run.log ]] || ! grep -q '^metric_value:' run.log; then
  printf '%s\n' "${commit}"$'\t'"0.000000"$'\t'"0.0"$'\t'"crash"$'\t'"${description}" >> results.tsv
  exit 2
fi

metric="$(metric_from_log)"
mem="$(mem_gb_from_log)"

if [[ ! -f best.metric ]]; then
  echo "$metric" > best.metric
  printf '%s\n' "${commit}"$'\t'"${metric}"$'\t'"${mem}"$'\t'"keep"$'\t'"${description}" >> results.tsv
  exit 0
fi

best="$(cat best.metric)"

if awk -v m="$metric" -v b="$best" 'BEGIN { exit (m + 0 < b + 0 - 1e-9) ? 0 : 1 }'; then
  echo "$metric" > best.metric
  printf '%s\n' "${commit}"$'\t'"${metric}"$'\t'"${mem}"$'\t'"keep"$'\t'"${description}" >> results.tsv
  exit 0
else
  printf '%s\n' "${commit}"$'\t'"${metric}"$'\t'"${mem}"$'\t'"discard"$'\t'"${description}" >> results.tsv
  exit 1
fi
