{
  inputs,
  pkgs,
  ...
}: {
  packages = [
    inputs.repo.packages.${pkgs.system}.definitively
    pkgs.graphviz
  ];
}
