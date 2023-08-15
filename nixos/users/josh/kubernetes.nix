{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  resource-capacity = pkgs.writeShellScriptBin "kubectl-resource_capacity" ''
    exec ${pkgs.kube-capacity}/bin/kube-capacity
  '';
in {
  home.packages = with pkgs; [
    kubectl
    kubecolor
    resource-capacity
    kubectl-tree
    kubectl-view-secret

    kubetail
    kubie
  ];
}
