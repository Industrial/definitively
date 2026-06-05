#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

TAG="${AUTORESEARCH_RUN_TAG:-$(date +%Y%m%d-%H%M%S)}"
BRANCH="autoresearch/${TAG}"

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "branch already exists: ${BRANCH}" >&2
  exit 1
fi

git checkout -b "${BRANCH}"
echo "${TAG}" > .run_tag
echo "created branch ${BRANCH}"
