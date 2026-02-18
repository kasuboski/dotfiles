{
  inputs,
  outputs,
  config,
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
  ];

  nixpkgs.overlays = [outputs.overlays.default];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.nvidiaSettings = true;
  hardware.nvidia.open = false;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  boot.kernelModules = ["nct6775"] ++ ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  networking.hostName = "forge";
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

  system.stateVersion = "25.11";
}
