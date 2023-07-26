{
  pkgs,
  lib,
  config,
  ...
}: {
  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = ["/share/fish"];
  programs.fish.enable = true;
  programs.fish.shellInit = lib.strings.concatStringsSep "\n" [
    ''
      # Nix
      if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
        source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      end
      # not sure why this isn't happening already
      fish_add_path -a /run/current-system/sw/bin
      # End Nix
    ''
  ];
  users.users.josh = {
    home = "/Users/josh";
    shell = pkgs.fish;
  };

  home-manager.users.josh = import ./home.nix;
}
