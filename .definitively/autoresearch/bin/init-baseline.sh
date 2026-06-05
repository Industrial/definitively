#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

metric="$(metric_from_log)"
echo "$metric" > best.metric
mem="$(mem_gb_from_log)"
commit="$(short_commit)"
printf '%s\n' "${commit}"$'\t'"${metric}"$'\t'"${mem}"$'\t'"keep"$'\t'"baseline" >> results.tsv
echo "baseline metric_value=${metric}"
