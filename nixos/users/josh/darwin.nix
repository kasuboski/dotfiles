{
  pkgs,
  config,
  ...
}: {
  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = ["/share/fish"];
  programs.fish.enable = true;
  users.users.josh = {
    home = "/Users/josh";
    shell = pkgs.fish;
  };

  home-manager.users.josh = import ./home.nix;
}
