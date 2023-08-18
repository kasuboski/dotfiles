{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [
    ../josh/home.nix
  ];

  home.username = lib.mkForce "root";
  home.homeDirectory = "/root";
}
