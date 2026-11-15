{
  lib,
  pkgs,
  ...
}: let
  pool = "/srv/forge-data";
  bindings = {
    "/home/josh/projects" = "development/projects";
    "/home/josh/.local/share/t3code" = "development/t3code";
    "/home/josh/.pi" = "development/pi";
    "/var/lib/docker" = "docker";
  };
in {
  imports = [./data-disko.nix ./storage-tools.nix];

  local.persistence.docker = false;

  fileSystems =
    lib.mapAttrs (_: relative: {
      device = "${pool}/${relative}";
      fsType = "none";
      options = ["bind" "nofail"];
      depends = [pool];
    })
    bindings;

  # Keep the OS bootable without the data pool, but fail dependent services
  # closed instead of writing into underlying SATA directories.
  systemd.services.t3code.unitConfig.RequiresMountsFor = [
    "/home/josh/projects"
    "/home/josh/.local/share/t3code"
    "/home/josh/.pi"
  ];
  systemd.services.docker.unitConfig.RequiresMountsFor = ["/var/lib/docker"];

  virtualisation.docker.storageDriver = "overlay2";
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [pool];
    interval = "monthly";
  };
  environment.systemPackages = [pkgs.smartmontools];
}
