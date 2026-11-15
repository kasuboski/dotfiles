# Standalone data-only declaration: safe to evaluate without the SATA layout.
# Shared by storage.nix for normal mounts and storage-tools.nix for isolated provisioning.
let
  intel = "/dev/disk/by-id/nvme-INTEL_SSDPEKNU020TZ_PHKA3136006P2P0C";
  crucial = "/dev/disk/by-id/nvme-CT2000P3PSSD8_2339E8790D45";
in {
  disko.devices.disk = {
    # Disko creates devices in dependency/alphabetical order. Prepare the Intel
    # member first; create the shared filesystem only after both GPTs exist.
    forge-data-a = {
      type = "disk";
      device = intel;
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          label = "forge-data-a";
          device = "${intel}-part1";
        };
      };
    };
    forge-data-b = {
      type = "disk";
      device = crucial;
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          label = "forge-data-b";
          device = "${crucial}-part1";
          content = {
            type = "btrfs";
            extraArgs = ["-L" "forge-data" "-d" "single" "-m" "raid1" "${intel}-part1"];
            mountpoint = "/srv/forge-data";
            mountOptions = ["subvolid=5" "compress=zstd" "noatime" "nofail" "x-systemd.device-timeout=10s"];
            # Ordinary directories inside development are created by migration;
            # nested subvolumes would break the shared snapshot boundary.
            subvolumes = {
              development = {};
              docker = {};
            };
          };
        };
      };
    };
  };
}
