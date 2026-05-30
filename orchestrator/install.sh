#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-${HOME}/.local}"
BINDIR="${BINDIR:-${PREFIX}/bin}"

if [[ ! -x "${ROOT}/bin/orchestrator" ]]; then
    echo "error: ${ROOT}/bin/orchestrator not found (extract the release tarball first)" >&2
    exit 1
fi

mkdir -p "${BINDIR}"
install -m 755 "${ROOT}/bin/orchestrator" "${BINDIR}/orchestrator"

echo "Installed orchestrator to ${BINDIR}/orchestrator"
echo "Ensure ${BINDIR} is on your PATH."
