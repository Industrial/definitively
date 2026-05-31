{
  lib,
  beamPackages,
  fetchMixDeps,
  mixRelease,
}: let
  inherit (beamPackages) elixir_1_18 erlang fetchMixDeps mixRelease;

  pname = "definitively";
  version = "0.2.0";
  src = ../definitively;
  elixir = elixir_1_18;
in
  (mixRelease {
    inherit
      pname
      version
      src
      elixir
      ;

    escriptBinName = "definitively";
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
      description = "FSM workflow definitively for CLI and LLM tasks";
      license = lib.licenses.mit;
      mainProgram = "definitively";
    };
  }).overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/definitively \
          --prefix PATH : ${lib.makeBinPath [erlang elixir]}
      '';
  })
