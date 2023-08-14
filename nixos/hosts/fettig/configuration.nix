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
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.extraSpecialArgs = {inherit inputs;};
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
    {nixpkgs.overlays = [(import ../../overlays)];}
    ./storage.nix
    ./cachix.nix
    ./ephemeral.nix
    ./observability.nix
    ../../users/josh
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "fettig"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";
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
  boot.kernelModules = ["nct6775"];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    htop
    git
    lm_sensors
    pipes-rs
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

  services.avahi = {
    enable = true;
    nssmdns = true;
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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
