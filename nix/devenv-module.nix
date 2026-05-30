{
  inputs,
  pkgs,
  ...
}: {
  packages = [
    inputs.repo.packages.${pkgs.system}.orchestrator
    pkgs.graphviz
  ];
}
