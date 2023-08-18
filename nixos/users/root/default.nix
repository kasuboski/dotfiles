{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../josh/home.nix
  ];

  home.username = "root";
}
