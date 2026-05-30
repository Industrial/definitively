class Orchestrator < Formula
  desc "FSM workflow orchestrator for CLI and LLM tasks"
  homepage "https://github.com/Industrial/definitively"
  version "0.1.0"
  license "MIT"

  depends_on "erlang"
  depends_on "graphviz"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Industrial/definitively/releases/download/orchestrator-v0.1.0/orchestrator-0.1.0-darwin-arm64.tar.gz"
      sha256 "5c4f75837bc55e73ece25f151d5fb9a21fd3832f52611a32b21b692b7f258c99"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Industrial/definitively/releases/download/orchestrator-v0.1.0/orchestrator-0.1.0-linux-x86_64.tar.gz"
      sha256 "2b0f5de3856ffe1407dd87fc152c3b8ec1c8f19ea624d1a05ea2a1c6d833c02d"
    end
  end

  def install
    bin.install "bin/orchestrator"
  end

  test do
    assert_match "usage", shell_output("#{bin}/orchestrator --help 2>&1", 1)
  end
end
