class Orchestrator < Formula
  desc "FSM workflow orchestrator for CLI and LLM tasks"
  homepage "https://github.com/tomwieland/test-haskell-web/tree/main/orchestrator"
  url "https://github.com/tomwieland/test-haskell-web.git",
      tag: "orchestrator-v0.1.0"
  version "0.1.0"
  license "MIT"

  depends_on "elixir"
  depends_on "graphviz" => :optional

  # After the first GitHub release, prefer prebuilt tarballs:
  # url "https://github.com/tomwieland/test-haskell-web/releases/download/orchestrator-v0.1.0/orchestrator-0.1.0-${OS}-#{Hardware::CPU.arch}.tar.gz"
  # def install; bin.install "bin/orchestrator"; end

  def install
    cd "orchestrator" do
      system "mix", "local.rebar", "--force"
      system "mix", "local.hex", "--force"
      system "mix", "deps.get", "--only", "prod"
      system "MIX_ENV=prod", "mix", "escript.build"
      bin.install "orchestrator"
    end
  end

  test do
    assert_match "usage", shell_output("#{bin}/orchestrator --help 2>&1", 1)
  end
end
