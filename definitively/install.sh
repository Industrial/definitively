#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-${HOME}/.local}"
BINDIR="${BINDIR:-${PREFIX}/bin}"

if [[ ! -x "${ROOT}/bin/definitively" ]]; then
    echo "error: ${ROOT}/bin/definitively not found (extract the release tarball first)" >&2
    exit 1
fi

mkdir -p "${BINDIR}"
install -m 755 "${ROOT}/bin/definitively" "${BINDIR}/definitively"

echo "Installed definitively to ${BINDIR}/definitively"
echo "Ensure ${BINDIR} is on your PATH."
echo "Run 'definitively init' in a project to scaffold .definitively/"
