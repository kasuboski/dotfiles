# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.impermanence.nixosModule
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.extraSpecialArgs = {inherit inputs;};
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      {nixpkgs.overlays = [(import ../../overlays)];}
      ./cachix.nix
      ./ephemeral.nix
      ../../users/josh
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ziel";

  nix = {
    settings = {
      trusted-users = ["root" "@wheel"];
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      system-features = ["kvm" "nixos-test" "benchmark" "big-parallel"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    htop
    git
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

  services.tailscale = {
    enable = true;
  };

  networking.firewall.allowedUDPPorts = [config.services.tailscale.port];

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/tailscale"
    ];
  };

  system.stateVersion = "23.11"; # Did you read the comment?

}

