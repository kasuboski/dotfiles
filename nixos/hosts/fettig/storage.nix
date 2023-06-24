{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  disks = [
    {
      type = "parity";
      name = "parity0";
      uuid = "667a66dd-b046-447e-8ed2-ed1a753f5c5d";
    }
    {
      type = "data";
      name = "data0";
      uuid = "1ed03d57-460e-4b7b-ab8c-d1dd09262a34";
    }
    {
      type = "data";
      name = "data1";
      uuid = "4befc870-7257-4134-960c-02dd755eab58";
    }
  ];
  parityDisks = builtins.filter (d: d.type == "parity") disks;
  dataDisks = builtins.filter (d: d.type == "data") disks;
  mkParityFs = disks:
    builtins.listToAttrs (builtins.map (d: {
        name = "/mnt/${d.name}";
        value = {
          device = "/dev/disk/by-uuid/${d.uuid}";
          fsType = "xfs";
        };
      })
      parityDisks);
  mkDataFs = disks:
    builtins.listToAttrs (builtins.concatMap (d: [
        {
          name = "/mnt/root/${d.name}";
          value = {
            device = "/dev/disk/by-uuid/${d.uuid}";
            fsType = "btrfs";
          };
        }
        {
          name = "/mnt/${d.name}";
          value = {
            device = "/dev/disk/by-uuid/${d.uuid}";
            fsType = "btrfs";
            options = ["subvol=data"];
          };
        }
        {
          name = "/mnt/snapraid-content/${d.name}";
          value = {
            device = "/dev/disk/by-uuid/${d.uuid}";
            fsType = "btrfs";
            options = ["subvol=content"];
          };
        }
      ])
      dataDisks);
in {
  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  fileSystems =
    {
      "/mnt/storage" = {
        #/mnt/disk* /mnt/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,cache.files=partial,moveonenospc=true,dropcacheonclose=true,minfreespace=100G,fsname=mergerfs 0 0
        device = lib.strings.concatMapStringsSep ":" (d: "/mnt/${d.name}") dataDisks;
        fsType = "fuse.mergerfs";
        options = ["defaults" "nofail" "nonempty" "allow_other" "use_ino" "cache.files=partial" "category.create=mfs" "moveonenospc=true" "dropcacheonclose=true" "minfreespace=100G" "fsname=mergerfs"];
      };
    }
    // mkParityFs disks
    // mkDataFs disks;

  # fileSystems."/mnt/parity0" = {
  #   device = "/dev/disk/by-uuid/667a66dd-b046-447e-8ed2-ed1a753f5c5d";
  #   fsType = "xfs";
  # };
  # fileSystems."/mnt/root/data0" = {
  #   device = "/dev/disk/by-uuid/1ed03d57-460e-4b7b-ab8c-d1dd09262a34";
  #   fsType = "btrfs";
  # };
  # fileSystems."/mnt/root/data1" = {
  #   device = "/dev/disk/by-uuid/4befc870-7257-4134-960c-02dd755eab58";
  #   fsType = "btrfs";
  # };

  # fileSystems."/mnt/data0" = {
  #   device = "/dev/disk/by-uuid/1ed03d57-460e-4b7b-ab8c-d1dd09262a34";
  #   fsType = "btrfs";
  #   options = ["subvol=data"];
  # };
  # fileSystems."/mnt/snapraid-content/data0" = {
  #   device = "/dev/disk/by-uuid/1ed03d57-460e-4b7b-ab8c-d1dd09262a34";
  #   fsType = "btrfs";
  #   options = ["subvol=content"];
  # };
  # fileSystems."/mnt/data1" = {
  #   device = "/dev/disk/by-uuid/4befc870-7257-4134-960c-02dd755eab58";
  #   fsType = "btrfs";
  #   options = ["subvol=data"];
  # };
  # fileSystems."/mnt/snapraid-content/data1" = {
  #   device = "/dev/disk/by-uuid/4befc870-7257-4134-960c-02dd755eab58";
  #   fsType = "btrfs";
  #   options = ["subvol=content"];
  # };

  # fileSystems."/mnt/storage" = {
  #   #/mnt/disk* /mnt/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,cache.files=partial,moveonenospc=true,dropcacheonclose=true,minfreespace=100G,fsname=mergerfs 0 0
  #   device = "/mnt/data0:/mnt/data1";
  #   fsType = "fuse.mergerfs";
  #   options = ["defaults" "nofail" "nonempty" "allow_other" "use_ino" "cache.files=partial" "category.create=mfs" "moveonenospc=true" "dropcacheonclose=true" "minfreespace=100G" "fsname=mergerfs"];
  # };
}
