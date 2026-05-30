#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
devenv_release="${repo_root}/.devenv/elixir-ls-release/language_server.sh"

if [[ -x "${devenv_release}" ]]; then
    exec "${devenv_release}" "$@"
fi

if [[ -n "${ELIXIR_LS_RELEASE:-}" && -x "${ELIXIR_LS_RELEASE}/language_server.sh" ]]; then
    exec "${ELIXIR_LS_RELEASE}/language_server.sh" "$@"
fi

store="$(nix-build '<nixpkgs>' -A elixir-ls --no-out-link 2>/dev/null || true)"
if [[ -n "${store}" && -x "${store}/scripts/language_server.sh" ]]; then
    exec "${store}/scripts/language_server.sh" "$@"
fi

echo "elixir-ls: could not find language_server.sh (run: devenv shell)" >&2
exit 127
