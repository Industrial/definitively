#!/usr/bin/env bash
# Fast verification gate — pre-commit parity (format → lint → doctor).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export DEFINITIVELY_WORKSPACE="$ROOT"

exec definitively run "$ROOT/.definitively/programs/pre-commit-gate.yml"
