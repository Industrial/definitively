{
  inputs,
  pkgs,
  ...
}: let
  # Moon from GitHub releases (x86_64-linux). See https://moonrepo.dev/docs/install
  moon = pkgs.stdenv.mkDerivation {
    pname = "moon-cli";
    version = "2.2.4";
    src = pkgs.fetchurl {
      url = "https://github.com/moonrepo/moon/releases/download/v2.2.4/moon_cli-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "0jxswvzjhglcfnj0xsyn5z5xy40llbc62ikfsp2hn8ax5al79cz7";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 moon $out/bin/moon
      runHook postInstall
    '';
    meta = {
      description = "Moon CLI (moonrepo)";
      homepage = "https://moonrepo.dev";
      license = pkgs.lib.licenses.mit;
      platforms = pkgs.lib.platforms.linux;
    };
  };

  # roam-code: architectural intelligence CLI + MCP (`roam mcp` needs `fastmcp`)
  # https://github.com/Cranot/roam-code — pin to a tagged release with MCP support.
  roam-code-src = pkgs.fetchFromGitHub {
    owner = "Cranot";
    repo = "roam-code";
    rev = "9023ed76922d61ae4514d15e9d81b86ddfaf1569"; # v11.2.0
    hash = "sha256-hE1gihZlJUQ8e8dOOpsxQM3b2KgvPAsU4wsJclmkptc=";
  };
  roam-code = pkgs.python3Packages.buildPythonApplication rec {
    pname = "roam-code";
    version = "11.2.0";
    src = roam-code-src;
    format = "pyproject";
    nativeBuildInputs = with pkgs.python3Packages; [setuptools wheel];
    propagatedBuildInputs = with pkgs.python3Packages; [
      click
      tree-sitter
      tree-sitter-language-pack
      networkx
      fastmcp
    ];
    doCheck = false;
  };

  # lean-ctx: MCP context runtime + shell compression (https://github.com/yvgude/lean-ctx)
  lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
    pname = "lean-ctx";
    version = "3.1.5";
    src = pkgs.fetchCrate {
      inherit pname version;
      hash = "sha256-WrLKCd6YzN5fxmBlyv9XSvAKXEtMbhuskyeDeLNFG2w=";
    };
    cargoHash = "sha256-n/xrYp8OLkmjbm3hjS9Mzx18VHs8Oh4Op767NM6rmI0=";
    doCheck = false;
  };

  # BEAM: pin Erlang/OTP and Elixir as a matched pair (see nixpkgs beam.packages).
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
  beamPackages = pkgs-unstable.beam.packages.erlang_27;

  # Launcher scripts at the path ElixirLS expects (language_server.sh, elixir_check.sh).
  elixirLsRelease = pkgs.runCommand "elixir-ls-vscode-release" {} ''
    mkdir -p $out
    for script in ${pkgs.elixir-ls}/scripts/*; do
      ln -s "$script" $out/$(basename "$script")
    done
  '';
in {
  name = "project-template";

  imports = [
    inputs.repo.devenvModules.definitively
  ];

  dotenv = {
    enable = true;
  };

  # cachix = {
  #   pull = ["project-template"];
  #   push = "project-template";
  # };

  # Languages
  languages = {
    javascript = {
      enable = true;
      bun = {
        enable = true;
      };
    };

    typescript = {
      enable = true;
    };

    rust = {
      enable = true;
      channel = "stable";
      components = [
        "cargo"
        "clippy"
        "rust-analyzer"
        "rustc"
        "rustfmt"
        "llvm-tools"
      ];
      targets = [];
    };

    # uv venv at `.devenv/state/venv` — Serena MCP (`scripts/serena-mcp-wrapper.sh`); see pyproject.toml [dependency-groups].
    python = {
      enable = true;
      uv = {
        enable = true;
        sync = {
          enable = true;
          arguments = [
            "--no-install-project"
            "--group"
            "serena"
          ];
        };
      };
    };

    # FSM definitively CLI — `definitively/` Mix project (gen_statem, CLI + MCP later).
    erlang = {
      enable = true;
      package = beamPackages.erlang;
    };

    elixir = {
      enable = true;
      package = beamPackages.elixir_1_18;
    };
  };

  env = {
    RUST_BACKTRACE = "1";
    CARGO_TERM_COLOR = "always";
    RUSTC_WRAPPER = "sccache";
    MOON_TOOLCHAIN_FORCE_GLOBALS = "rust";
    MOON_CONCURRENCY = "1";
    ELIXIR_LS_RELEASE = "${elixirLsRelease}";
  };

  # Development packages
  packages = with pkgs; [
    inputs.rust-symphony.packages.${pkgs.system}.default
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.beads
    cachix

    clippy
    rust-analyzer
    rustc

    direnv
    prek

    alejandra

    cargo-watch
    cargo-audit
    cargo-llvm-cov
    cargo-nextest

    sccache
    mold

    git
    gh
    uv

    roam-code
    lean-ctx

    moon

    actionlint
    alejandra
    beautysh
    biome
    deadnix
    rustfmt
    taplo
    treefmt
    vulnix
    yamlfmt

    # jq — JSON CLI for shell hooks and automation scripts
    jq
    # Native libs for uv-installed wheels (Serena / transitive deps) on NixOS
    zlib
    pkgs.stdenv.cc.cc.lib
    inotify-tools
  ];

  scripts = {
    prek-install = {
      exec = ''
        prek install -q --overwrite
      '';
    };

    moon-sync = {
      exec = ''
        moon sync
      '';
    };

    # Pre-commit: fast gates (format + credo + doctor doc/spec coverage)
    pre-commit = {
      exec = ''
        mkdir -p "$DEVENV_ROOT/tmp"
        export TMPDIR="$DEVENV_ROOT/tmp"
        export MOON_TOOLCHAIN_FORCE_GLOBALS=rust
        export MOON_CONCURRENCY=1
        moon run :format :lint :doctor :test :coverage :docs :build
      '';
    };

    # Pre-push: full definitively pipeline (tests, coverage, ExDoc, compile)
    pre-push = {
      exec = ''
        mkdir -p "$DEVENV_ROOT/tmp"
        export TMPDIR="$DEVENV_ROOT/tmp"
        export MOON_TOOLCHAIN_FORCE_GLOBALS=rust
        export MOON_CONCURRENCY=1
        moon run :format :lint :doctor :test :coverage :docs :build
      '';
    };

    mix-setup = {
      exec = ''
        cd definitively
        mix local.hex --force
        mix local.rebar --force
        mix deps.get
      '';
    };

    mix-test = {
      exec = ''
        cd definitively && mix test
      '';
    };

    definitively-escript = {
      exec = ''
        cd "$DEVENV_ROOT/definitively"
        mix escript.build --force
      '';
    };
  };

  enterShell = ''
    prek-install
    moon-sync

    # uv sync installs Serena into `.devenv/state/venv/bin`; devenv does not prepend by default.
    export PATH="''${DEVENV_ROOT}/.devenv/state/venv/bin:''${PATH}"

    mkdir -p "$HOME/.cache/sccache"
    chmod 755 "$HOME/.cache/sccache" 2>/dev/null || true

    export MIX_ENV=dev
    export DEFINITIVELY_WORKSPACE="$DEVENV_ROOT"

    # Hex ETS cache can corrupt (:badfile); remove before deps.get so direnv stays clean.
    hex_cache="$HOME/.hex/cache.ets"
    if [ -f "$hex_cache" ]; then
      export HEX_CACHE="$hex_cache"
      if ! elixir -e "case :ets.file2tab(String.to_charlist(System.get_env(\"HEX_CACHE\"))) do {:ok, _} -> :ok; _ -> System.halt(1) end" 2>/dev/null; then
        echo "devenv: removing corrupted Hex cache ($hex_cache)"
        rm -f "$hex_cache"
      fi
      unset HEX_CACHE
    fi

    (cd "$DEVENV_ROOT/definitively" && mix deps.get --quiet) || true

    if [ "''${DEFINITIVELY_FROM_SOURCE:-}" = "1" ]; then
      definitively-escript
      export PATH="$DEVENV_ROOT/definitively:$PATH"
    fi

    # ElixirLS override dir (also used by scripts/elixir-ls-release/*.sh wrappers)
    mkdir -p "$DEVENV_ROOT/.devenv/elixir-ls-release"
    for script in language_server.sh elixir_check.sh; do
      ln -sfn "${elixirLsRelease}/$script" "$DEVENV_ROOT/.devenv/elixir-ls-release/$script"
    done
  '';
}
