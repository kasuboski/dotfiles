{ config, lib, pkgs, ... }:
{
  home = {
    stateVersion = "23.05";
    username = "josh";
    homeDirectory = "/home/${config.home.username}";
  };    
  programs = {
    home-manager.enable = true;
    git.enable = true;
    direnv.enable = true;
    fish.enable = true;
  };
}
