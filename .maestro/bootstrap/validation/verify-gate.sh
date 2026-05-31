#!/usr/bin/env bash
# Maestro verification gate — full CI parity via definitively pre-push program.
# Run from repo root; records exit code for maestro evidence.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export DEFINITIVELY_WORKSPACE="$ROOT"

exec definitively run "$ROOT/.definitively/programs/pre-push-gate.yml"
