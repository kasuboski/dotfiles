{pkgs, ...}: {
  imports = [../common/darwin.nix];

  # This is a fresh nix-darwin installation.
  system.stateVersion = 6;

  users.users.jkasper = {
    home = "/Users/jkasper";
    shell = pkgs.fish;
  };

  home-manager.users.jkasper = {
    imports = [
      ../../users/josh/home.nix
      ../../users/josh/work.nix
    ];
    home = {
      username = "jkasper";
      stateVersion = "26.05";
    };
    # Fish requests a man cache, but current Home Manager uses macOS's man.
    programs.man.generateCaches = false;
  };
}
