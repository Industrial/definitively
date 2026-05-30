#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${HEX_API_KEY:-}" ]]; then
    echo "error: HEX_API_KEY secret is not set" >&2
    exit 1
fi

if ! curl -fsS -H "Authorization: ${HEX_API_KEY}" https://hex.pm/api/users/me >/dev/null; then
    echo "error: HEX_API_KEY is missing or invalid (hex.pm rejected the key)" >&2
    exit 1
fi

echo "Hex API key validated"
