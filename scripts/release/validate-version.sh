#!/usr/bin/env bash
set -euo pipefail

TAG="${1:?usage: validate-version.sh definitively-vX.Y.Z}"
VERSION="${TAG#definitively-v}"

if [[ -z "${VERSION}" || "${VERSION}" == "${TAG}" ]]; then
    echo "error: tag must look like definitively-vX.Y.Z (got: ${TAG})" >&2
    exit 1
fi

MIX_VERSION="$(
  grep -E '^\s+version:' definitively/mix.exs \
    | head -n 1 \
    | sed -E 's/.*"([^"]+)".*/\1/'
)"

if [[ "${MIX_VERSION}" != "${VERSION}" ]]; then
  echo "error: tag ${TAG} implies version ${VERSION}, mix.exs has ${MIX_VERSION}" >&2
  exit 1
fi

echo "ok: tag ${TAG} matches definitively/mix.exs version ${MIX_VERSION}"
