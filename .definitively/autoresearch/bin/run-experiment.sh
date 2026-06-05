#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

elixir eval.exs > run.log 2>&1
