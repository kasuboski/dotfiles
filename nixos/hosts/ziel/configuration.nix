# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.impermanence.nixosModule
    ../common/global
    ../common/optional/ephemeral.nix
    {nixpkgs.overlays = [(import ../../overlays)];}
    ../../users/josh
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ziel";

  environment.systemPackages = with pkgs; [
    lm_sensors
  ];

  users.mutableUsers = false;

  services.netdata.enable = true;
  networking.firewall.allowedTCPPorts = [19999];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
  };

  system.stateVersion = "23.11"; # Did you read the comment?
}
