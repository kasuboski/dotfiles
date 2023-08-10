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
    kube-capacity
    kubectl-tree
    kubectl-view-secret

    kubetail
    kubie
  ];
}
