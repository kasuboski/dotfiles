{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.mac-app-util.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.extraSpecialArgs = {inherit inputs;};
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
    {nixpkgs.overlays = [outputs.overlays.default];}
    ../../users/josh/darwin.nix
    {home-manager.users.josh = import ../../users/josh/work.nix;}
  ];

  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    settings = {
      trusted-users = ["@admin"];
      experimental-features = ["nix-command" "flakes"];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };
  };

  ids.gids.nixbld = 30000;

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
  '';

  environment.shells = with pkgs; [bashInteractive zsh fish];

  system.stateVersion = 5;
}
