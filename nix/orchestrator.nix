{
  lib,
  beamPackages,
  fetchMixDeps,
  mixRelease,
}: let
  inherit (beamPackages) elixir_1_18 erlang fetchMixDeps mixRelease;

  pname = "orchestrator";
  version = "0.1.0";
  src = ../orchestrator;
  elixir = elixir_1_18;
in
  (mixRelease {
    inherit
      pname
      version
      src
      elixir
      ;

    escriptBinName = "orchestrator";
    mixEnv = "prod";
    stripDebug = true;

    mixFodDeps = fetchMixDeps {
      pname = "mix-deps-${pname}";
      inherit
        src
        version
        elixir
        ;
      mixEnv = "prod";
      hash = "sha256-AoBGheC1jic0+izmmyIsLb/iuJWXenWUQXK7YHT3Qik=";
    };

    meta = {
      description = "FSM workflow orchestrator for CLI and LLM tasks";
      license = lib.licenses.mit;
      mainProgram = "orchestrator";
    };
  }).overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/orchestrator \
          --prefix PATH : ${lib.makeBinPath [erlang elixir]}
      '';
  })
