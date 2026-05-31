{
  description = "test-haskell-web development flake";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
  }: let
    systems = nixpkgs.lib.systems.flakeExposed;
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
        };
        beamPackages = pkgs-unstable.beam.packages.erlang_27;
        definitively = pkgs.callPackage ./nix/definitively.nix {
          inherit beamPackages;
          inherit (beamPackages) fetchMixDeps mixRelease;
        };
      in {
        inherit definitively;
        default = definitively;
      }
    );

    devenvModules.definitively = import ./nix/devenv-module.nix;
  };
}
