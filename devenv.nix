{
  inputs,
  pkgs,
  ...
}: let
  # Moon from GitHub releases (x86_64-linux). See https://moonrepo.dev/docs/install
  moon = pkgs.stdenv.mkDerivation {
    pname = "moon-cli";
    version = "2.0.4";
    src = pkgs.fetchurl {
      url = "https://github.com/moonrepo/moon/releases/download/v2.0.4/moon_cli-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "0n7w3pmnwaxk0cy63ms97g609z696698a4qdrssnsa7cs8wgxxc8";
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
in {
  name = "project-template";

  dotenv = {
    enable = true;
  };

  cachix = {
    pull = ["project-template"];
    push = "project-template";
  };

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
  };

  env = {
    RUST_BACKTRACE = "1";
    CARGO_TERM_COLOR = "always";
    RUSTC_WRAPPER = "sccache";
    MOON_TOOLCHAIN_FORCE_GLOBALS = "rust";
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

    # Cursor hooks (format-after-edit, enforce-devenv) + postgres MCP wrapper
    jq
    # Native libs for uv-installed wheels (Serena / transitive deps) on NixOS
    zlib
    pkgs.stdenv.cc.cc.lib
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

    # Pre-push: run full check via moon (used by prek hook)
    pre-push = {
      exec = ''
        export MOON_TOOLCHAIN_FORCE_GLOBALS=rust
        moon run :format :check :lint :build :test :audit :check-docs
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
  '';
}
