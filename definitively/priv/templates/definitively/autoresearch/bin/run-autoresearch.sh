#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

RUN_TAG="${1:-$(date +%Y%m%d-%H%M%S)}"
export AUTORESEARCH_RUN_TAG="$RUN_TAG"

if command -v definitively >/dev/null 2>&1; then
  DEFINITIVELY="definitively"
elif [[ -x "$ROOT/definitively/_build/escript/definitively" ]]; then
  DEFINITIVELY="$ROOT/definitively/_build/escript/definitively"
else
  echo "definitively not on PATH; run from devenv shell or build escript" >&2
  exit 1
fi

exec "$DEFINITIVELY" run "$ROOT/.definitively/programs/autoresearch.yml"
