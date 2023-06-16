{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.vscode-server.homeModules.default
  ];
  services.vscode-server.enable = true;

  home = {
    stateVersion = "23.05";
    username = "josh";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
    git.enable = true;
    gh.enable = true;
    bat = {
      enable = true;
      themes = {
        catppuccinMocha = builtins.readFile ../../../dot_config/bat/themes/Catppuccin-mocha.tmTheme;
      };
      config = {
        theme = "catppuccinMocha";
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
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
