{ pkgs, config, ...}:
{
  programs.fish.enable = true;
  users.users.josh = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzR7zD/n14hIPjRWN8lGIj2zSmmFaqBX2Qhf80TOmdQ josh.kasuboski@gmail.com"
    ];
    passwordFile = "/persist/passwords/josh";
  };

  home-manager.users.josh = import ./home.nix;
}
