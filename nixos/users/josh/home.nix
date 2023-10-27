{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  homePrefix =
    if isDarwin
    then "/Users"
    else "/home";
  manpager = pkgs.writeShellScriptBin "manpager" "sh -c 'col -bx | bat -l man -p'";
in {
  imports = [
    inputs.vscode-server.homeModules.default
    ./kubernetes.nix
  ];
  services.vscode-server.enable = true;

  home = {
    stateVersion = "23.05";
    username = "josh";
    homeDirectory = lib.mkDefault "${homePrefix}/${config.home.username}";
  };

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    MANPAGER = "${manpager}/bin/manpager";
  };

  xdg.enable = true;
  xdg.configFile."fish/themes/CatppuccinMocha.theme".source = ../../../dot_config/private_fish/themes/CatppuccinMocha.theme;

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      userName = "Josh Kasuboski";
      userEmail = "josh.kasuboski@gmail.com";
      ignores = [
        ".direnv"
        "result"
      ];
      extraConfig = {
        init.defaultBranch = "main";
        github.user = "kasuboski";
        color.ui = true;
      };
      delta.enable = true;
    };
    gh.enable = true;
    bat = {
      enable = true;
      themes = {
        catppuccinMocha = {src = ../../../dot_config/bat/themes/Catppuccin-mocha.tmTheme;};
      };
      config = {
        theme = "catppuccinMocha";
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fish = {
      enable = true;
      interactiveShellInit = lib.strings.concatStringsSep "\n" [
        "fish_config theme choose CatppuccinMocha"
      ];
      shellInit = lib.strings.concatStringsSep "\n" [
        ''
          # Nix
          if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
            source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
          end
          # not sure why this isn't happening already
          fish_add_path -a /run/current-system/sw/bin
          fish_add_path -a /etc/profiles/per-user/${config.home.username}/bin
          # this for sure needs to be first
          fish_add_path -p /run/wrappers/bin
          # End Nix
        ''
      ];
      shellAliases = {
        kgpo = "k get pods";
      };
      functions =
        {
          k = {
            wraps = "kubectl";
            description = "alias kubectl";
            body = ''
              if type -q kubecolor
                kubecolor $argv
              else
                kubectl $argv
              end
            '';
          };
          help = {
            description = "send command help info to bat";
            body = ''
              $argv --help 2>&1 | bat -l help -p
            '';
          };
        }
        // (lib.optionalAttrs isDarwin {
          flush_dns = "sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder";
        });
    };
    fzf.enable = true;
    lsd = {
      enable = true;
      enableAliases = true;
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      extraConfig = ''
        set number
        set expandtab
        set tabstop=2
        set shiftwidth=2
      '';
    };
    rtx = {
      enable = true;
    };
    starship = {
      enable = true;
      settings = lib.importTOML ../../../dot_config/starship.toml;
    };
    zoxide.enable = true;
  };

  home.packages = with pkgs; [
    alejandra
    comma
    du-dust
    fd
    jq
    loft
    ripgrep
    yq
  ];
}
