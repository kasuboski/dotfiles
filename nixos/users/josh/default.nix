{
  pkgs,
  config,
  ...
}: {
  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = ["/share/fish"];
  programs.fish.enable = true;
  users.users.josh = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ["wheel" "shares" "docker"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzR7zD/n14hIPjRWN8lGIj2zSmmFaqBX2Qhf80TOmdQ josh.kasuboski@gmail.com"
    ];
    passwordFile = "/persist/passwords/josh";
  };

  home-manager.users.josh = import ./home.nix;
}
