{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/ata-ADATA_SU800_2H2020010171";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Explicit priorities preserve the existing on-disk order: EFI, swap, root.
          boot = {
            priority = 1;
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
            priority = 3;
            name = "nixos";
            size = "100%";
            # Match the existing layout's unused 6 GiB tail; swap is before root.
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
            priority = 2;
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
