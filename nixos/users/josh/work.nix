{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  home.programs = {
    mise.enable = true;
  };
  home.packages = with pkgs; [
    azure-cli
    kubernetes-helm
    loft
    pipenv
  ];
}
