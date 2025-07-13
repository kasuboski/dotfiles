{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  programs = {
    mise.enable = true;
  };
  home.packages = with pkgs; [
    azure-cli
    crane
    kubernetes-helm
    oras
    pipenv
  ];
}
