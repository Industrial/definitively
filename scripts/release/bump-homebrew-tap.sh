#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
CHECKSUMS_FILE="${CHECKSUMS_FILE:?CHECKSUMS_FILE is required}"
TAP_REPO="${HOMEBREW_TAP_REPO:-idcleartomwieland/homebrew-tap}"
TAP_TOKEN="${HOMEBREW_TAP_TOKEN:?HOMEBREW_TAP_TOKEN is required}"

TAG="orchestrator-v${VERSION}"
BASE_URL="https://github.com/Industrial/definitively/releases/download/${TAG}"

LINUX_SHA="$(grep 'linux-x86_64' "${CHECKSUMS_FILE}" | awk '{print $1}')"
DARWIN_SHA="$(grep 'darwin-arm64' "${CHECKSUMS_FILE}" | awk '{print $1}')"

if [[ -z "${LINUX_SHA}" || -z "${DARWIN_SHA}" ]]; then
    echo "error: could not parse linux/darwin checksums from ${CHECKSUMS_FILE}" >&2
    cat "${CHECKSUMS_FILE}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

git clone "https://x-access-token:${TAP_TOKEN}@github.com/${TAP_REPO}.git" "${WORKDIR}/tap"
mkdir -p "${WORKDIR}/tap/Formula"

cat > "${WORKDIR}/tap/Formula/orchestrator.rb" << RUBY
class Orchestrator < Formula
  desc "FSM workflow orchestrator for CLI and LLM tasks"
  homepage "https://github.com/Industrial/definitively"
  version "${VERSION}"
  license "MIT"

  depends_on "erlang"
  depends_on "graphviz"

  on_macos do
    if Hardware::CPU.arm?
      url "${BASE_URL}/orchestrator-${VERSION}-darwin-arm64.tar.gz"
      sha256 "${DARWIN_SHA}"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "${BASE_URL}/orchestrator-${VERSION}-linux-x86_64.tar.gz"
      sha256 "${LINUX_SHA}"
    end
  end

  def install
    bin.install "bin/orchestrator"
  end

  test do
    assert_match "usage", shell_output("#{bin}/orchestrator --help 2>&1", 1)
  end
end
RUBY

cd "${WORKDIR}/tap"
git add Formula/orchestrator.rb
if git diff --cached --quiet; then
    echo "Homebrew formula unchanged"
    exit 0
fi

git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -m "chore(orchestrator): bump to ${VERSION}"
git push origin HEAD
echo "pushed Formula/orchestrator.rb ${VERSION} to ${TAP_REPO}"
