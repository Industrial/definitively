#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
devenv_release="${repo_root}/.devenv/elixir-ls-release/elixir_check.sh"

if [[ -x "${devenv_release}" ]]; then
    exec "${devenv_release}" "$@"
fi

if [[ -n "${ELIXIR_LS_RELEASE:-}" && -x "${ELIXIR_LS_RELEASE}/elixir_check.sh" ]]; then
    exec "${ELIXIR_LS_RELEASE}/elixir_check.sh" "$@"
fi

store="$(nix-build '<nixpkgs>' -A elixir-ls --no-out-link 2>/dev/null || true)"
if [[ -n "${store}" && -x "${store}/scripts/elixir_check.sh" ]]; then
    exec "${store}/scripts/elixir_check.sh" "$@"
fi

echo "elixir-ls: could not find elixir_check.sh (run: devenv shell)" >&2
exit 127
