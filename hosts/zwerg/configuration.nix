{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko-config.nix
    ./hardware-configuration.nix
    inputs.impermanence.nixosModule
    ../common/global
    ../common/optional/ephemeral.nix
    ../../users/josh
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "zwerg";
  networking.useDHCP = true;
  time.timeZone = "America/Chicago";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    # Required by nixos-anywhere for the kexec reboot process
    extraConfig = ''
      AcceptEnv KEXEC_*
    '';
  };

  fileSystems."/persist".neededForBoot = true;

  system.stateVersion = "25.05";
}
