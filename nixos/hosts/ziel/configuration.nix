# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  outputs,
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
    ../../users/josh
    ./home-assistant.nix
    ./blocky.nix
    ./monitoring.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_testing; # need for the intel wifi/BT
  # https://forums.gentoo.org/viewtopic-t-1163072.html?sid=90dba32692ee2125aa582fe839c53050
  hardware.firmware = [
    (
      pkgs.runCommandNoCC "ibt-0040-1050" {} ''
        mkdir -p $out/lib/firmware/intel
        cp ${pkgs.linux-firmware}/lib/firmware/intel/ibt-1040-4150.sfi $out/lib/firmware/intel/ibt-0040-1050.sfi
      ''
    )
  ];

  networking.hostName = "ziel";

  environment.systemPackages = with pkgs; [
    lm_sensors
  ];

  hardware.bluetooth.enable = true;
  networking.wireless.enable = true;

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
