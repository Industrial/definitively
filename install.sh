#!/usr/bin/env bash
# Install orchestrator from GitHub releases.
# Usage: curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
set -euo pipefail

REPO="${ORCHESTRATOR_INSTALL_REPO:-Industrial/definitively}"
PREFIX="${PREFIX:-${HOME}/.local}"
BINDIR="${BINDIR:-${PREFIX}/bin}"
VERIFY="${ORCHESTRATOR_VERIFY:-1}"
TAG="${ORCHESTRATOR_VERSION:-}"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"

usage() {
    cat <<EOF
Install orchestrator from GitHub releases.

Quick install:
  curl -fsSL ${RAW_URL} | bash

Pin a release:
  curl -fsSL ${RAW_URL} | bash -s -- --version orchestrator-v0.1.0

Environment variables:
  ORCHESTRATOR_INSTALL_REPO   GitHub owner/repo (default: Industrial/definitively)
  ORCHESTRATOR_VERSION        Release tag (default: latest orchestrator-v* release)
  PREFIX                      Install prefix (default: \$HOME/.local)
  BINDIR                      Binary directory (default: \$PREFIX/bin)
  ORCHESTRATOR_VERIFY         Verify SHA256 checksum when 1 (default: 1)

Supported release platforms: linux-x86_64, darwin-arm64
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

download() {
    local url="$1" dest="$2"
    if have curl; then
        curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"
    elif have wget; then
        wget -qO "$dest" "$url"
    else
        die "curl or wget is required"
    fi
}

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}-${arch}" in
        Linux-x86_64) echo "linux-x86_64" ;;
        Darwin-arm64) echo "darwin-arm64" ;;
        Linux-aarch64 | Linux-arm64)
            die "linux arm64 is not published yet (need linux-aarch64 release asset)"
            ;;
        Darwin-x86_64)
            die "macOS x86_64 is not published yet (need darwin-x86_64 release asset)"
            ;;
        *)
            die "unsupported platform: ${os}-${arch}"
            ;;
    esac
}

resolve_tag() {
    if [[ -n "${TAG}" ]]; then
        echo "${TAG}"
        return
    fi

    local json tag
    json="$(curl -fsSL -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/releases?per_page=30")"
    tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\(orchestrator-v[^"]*\)".*/\1/p' | head -n 1)"

    if [[ -z "${tag}" ]]; then
        die "no orchestrator-v* release found at https://github.com/${REPO}/releases"
    fi
    echo "${tag}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --version)
            [[ $# -ge 2 ]] || die "--version requires a tag (e.g. orchestrator-v0.1.0)"
            TAG="$2"
            shift 2
            ;;
        *)
            die "unknown argument: $1 (try --help)"
            ;;
    esac
done

if [[ -z "${BASH_VERSION:-}" ]]; then
    die "pipe this script to bash: curl -fsSL ${RAW_URL} | bash"
fi

PLATFORM="$(detect_platform)"
TAG="$(resolve_tag)"
VERSION="${TAG#orchestrator-v}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"
ARCHIVE="orchestrator-${VERSION}-${PLATFORM}.tar.gz"
URL="${BASE}/${ARCHIVE}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "=> Installing orchestrator ${TAG} (${PLATFORM})"
download "$URL" "${tmpdir}/${ARCHIVE}"

if [[ "${VERIFY}" == "1" ]]; then
    checksums="${tmpdir}/checksums.txt"
    if curl -fsSL --retry 3 --retry-delay 1 -o "$checksums" "${BASE}/checksums.txt" 2>/dev/null \
        || { have wget && wget -qO "$checksums" "${BASE}/checksums.txt"; }; then
        expected="$(grep -F " ${ARCHIVE}" "$checksums" | awk '{print $1}' || true)"
        if [[ -n "${expected}" ]]; then
            if have sha256sum; then
                actual="$(sha256sum "${tmpdir}/${ARCHIVE}" | awk '{print $1}')"
            else
                actual="$(shasum -a 256 "${tmpdir}/${ARCHIVE}" | awk '{print $1}')"
            fi
            [[ "${actual}" == "${expected}" ]] || die "checksum mismatch for ${ARCHIVE}"
            echo "=> Checksum verified"
        fi
    fi
fi

tar -xzf "${tmpdir}/${ARCHIVE}" -C "$tmpdir"
root="$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d -name "orchestrator-${VERSION}-${PLATFORM}" | head -n 1)"
[[ -n "${root}" ]] || die "unexpected tarball layout"

PREFIX="${PREFIX}" BINDIR="${BINDIR}" bash "${root}/install.sh"

if ! command -v orchestrator >/dev/null 2>&1; then
    echo
    echo "Add ${BINDIR} to your PATH, for example:"
    echo "  export PATH=\"${BINDIR}:\$PATH\""
fi

if ! command -v escript >/dev/null 2>&1 && ! command -v erl >/dev/null 2>&1; then
    echo
    echo "note: orchestrator is an escript and needs Erlang/OTP 27+ on PATH at runtime."
    echo "      Install Erlang or use the Nix/devenv flake if you do not have it."
fi

echo
echo "=> Done. Try: orchestrator init"
