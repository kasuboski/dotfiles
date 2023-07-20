{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    kubectl
    kubecolor
    kubectl-tree
    kubectl-view-secret

    kubetail
    kubie
  ];
}
