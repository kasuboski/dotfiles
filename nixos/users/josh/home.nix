{ config, lib, pkgs, ... }:
{
  home = {
    stateVersion = "23.05";
    username = "josh";
    homeDirectory = "/home/${config.home.username}";
  };

  xdg.enable = true;
     
  programs = {
    home-manager.enable = true;
    git.enable = true;
    gh.enable = true;
    bat.enable = true;
    direnv.enable = true;
    fish.enable = true;
    fzf.enable = true;
    lsd = {
      enableAliases = true;
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
    starship = {
      enable = true;
      settings = lib.importTOML ../../../dot_config/starship.toml;
    };
    zoxide.enable = true;
  };

  home.packages = with pkgs; [
    comma
    fd
    jq
    yq
  ];
}
