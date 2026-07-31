{pkgs, ...}: {
  imports = [../common/darwin.nix];

  # Keep the state version from this machine's original installation.
  system.stateVersion = 5;

  nix = {
    linux-builder.enable = true;
    linux-builder.maxJobs = 4;
  };

  users.users.josh = {
    home = "/Users/josh";
    shell = pkgs.fish;
  };

  home-manager.users.josh = import ../../users/josh/home.nix;
}
