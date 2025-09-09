{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko-config.nix
    ./hardware-configuration.nix
    inputs.impermanence.nixosModule
    ../common/global
    ../common/optional/ephemeral.nix
    ../../users/josh
    ./plex.nix
  ];

  nixpkgs.overlays = [outputs.overlays.default];
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "zwerg";
  networking.useDHCP = true;
  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    lm_sensors
    pipes-rs
  ];

  services.netdata.enable = true;
  # https://github.com/NixOS/nixpkgs/issues/402135
  services.netdata.package = pkgs.netdataCloud;
  networking.firewall.allowedTCPPorts = [19999];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    # Required by nixos-anywhere for the kexec reboot process
    extraConfig = ''
      AcceptEnv KEXEC_*
    '';
  };

  fileSystems."/persist".neededForBoot = true;

  users.mutableUsers = false;

  system.stateVersion = "25.05";
}
