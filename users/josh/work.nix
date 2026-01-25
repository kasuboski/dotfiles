{pkgs, ...}: {
  home.packages = with pkgs; [
    azure-cli
    crane
    kubernetes-helm
    oras
    pipenv
  ];
}
