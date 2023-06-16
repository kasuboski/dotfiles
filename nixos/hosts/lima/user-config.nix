{
  inputs,
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.extraSpecialArgs = {inherit inputs;};
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # don't mess with same nixos user for now
      home-manager.users.josh = import ../../users/josh/home.nix;
    }
  ];

  environment.systemPackages = with pkgs; [
    vim
    htop
    git
    curl
    wget
    fish
  ];

  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = ["/share/fish"];
  programs.fish.enable = true;

  nix.settings.trusted-users = ["root" "@wheel" "josh"];

  virtualisation.docker.enable = true;
  users.users.josh.extraGroups = ["wheel" "docker"];

  home-manager.users.josh.home.homeDirectory = "/home/josh.linux";
  users.users.josh = {
    shell = "/run/current-system/sw/bin/fish";
    isNormalUser = true;
    group = "users";
    home = "/home/josh.linux";
  }; # Settings need to be specified here too so folders aren't overwritten/wiped
}
