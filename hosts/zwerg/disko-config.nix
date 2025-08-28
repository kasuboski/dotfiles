{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP4512Q-A0_50026B7686F81025";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "511M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "nixos";
            size = "100%";
            end = "-6G";
            content = {
              type = "btrfs";
              extraArgs = ["-L" "nixos"];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "/root-blank" = {};
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "/log" = {
                  mountpoint = "/var/log";
                  mountOptions = ["compress=zstd" "noatime"];
                };
              };
            };
          };
          swap = {
            name = "swap";
            size = "6G";
            content = {
              type = "swap";
              extraArgs = ["-L" "swap"];
            };
          };
        };
      };
    };
  };
}
