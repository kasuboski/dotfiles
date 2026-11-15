# Explicit build-only migration/recovery outputs. Nothing here is installed into
# the running system or executed by activation; see storage-migration.md.
{
  inputs,
  pkgs,
  ...
}: let
  # Never derive pool provisioning from forge's merged disko.devices, which
  # also includes the live SATA system disk.
  dataOnly = inputs.nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      inputs.disko.nixosModules.disko
      ./data-disko.nix
      {
        nixpkgs.pkgs = pkgs;
        disko.rootMountPoint = "/mnt/forge-data-disko";
        disko.checkScripts = true;
      }
    ];
  };
  dataDisko = assert builtins.attrNames dataOnly.config.disko.devices.disk == ["forge-data-a" "forge-data-b"];
  assert map (d: d.device) (builtins.attrValues dataOnly.config.disko.devices.disk)
  == [
    "/dev/disk/by-id/nvme-INTEL_SSDPEKNU020TZ_PHKA3136006P2P0C"
    "/dev/disk/by-id/nvme-CT2000P3PSSD8_2339E8790D45"
  ];
    dataOnly.config.system.build.destroyFormatMount;
  migration = pkgs.writeShellApplication {
    name = "forge-storage-migrate";
    runtimeInputs = with pkgs; [btrfs-progs coreutils docker findutils gawk git gnugrep nix rsync smartmontools sqlite systemd util-linux];
    text = builtins.replaceStrings ["@forgeDataDisko@"] ["${dataDisko}"] (builtins.readFile ../../scripts/forge-storage-migrate.sh);
  };
in {
  system.build.forgeStorageMigration = migration;
  system.build.forgeDataDisko = dataDisko;
}
