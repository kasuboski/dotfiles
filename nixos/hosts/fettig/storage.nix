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
  parityFs = builtins.listToAttrs (builtins.map (d: {
      name = "/mnt/${d.name}";
      value = {
        device = "/dev/disk/by-uuid/${d.uuid}";
        fsType = "xfs";
      };
    })
    parityDisks);
  dataFs = builtins.listToAttrs (builtins.concatMap (d: [
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
        name = "/mnt/${d.name}/.snapshots";
        value = {
          device = "/dev/disk/by-uuid/${d.uuid}";
          fsType = "btrfs";
          options = ["subvol=.snapshots"];
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
  snapperConfigs = builtins.listToAttrs (builtins.map (d: {
      name = "${d.name}";
      value = {
        SUBVOLUME = "/mnt/${d.name}";
        ALLOW_GROUPS = ["wheel"];
        SYNC_ACL = true;
      };
    })
    dataDisks);
in {
  environment.systemPackages = with pkgs; [
    mergerfs
    (callPackage ../../pkgs/snapraid-btrfs.nix {})
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
    // parityFs
    // dataFs;

  snapraid = {
    enable = true;
    sync.interval = "";
    scrub.interval = "";
    parityFiles = builtins.map (p: "/mnt/${p.name}/snapraid.parity") parityDisks;
    contentFiles =
      [
        "/var/snapraid.content"
      ]
      ++ builtins.map (d: "/mnt/snapraid-content/${d.name}/snapraid.content") dataDisks;
    dataDisks = builtins.listToAttrs (lib.lists.imap0 (i: d: {
        name = "d${toString i}";
        value = "/mnt/${d.name}";
      })
      dataDisks);
    exclude = [
      "*.unrecoverable"
      "/tmp/"
      "/lost+found/"
      "downloads/"
      "appdata/"
      "*.!sync"
      "/.snapshots/"
    ];
  };

  environment.persistence."/persist" = {
    files = [
      "/var/snapraid.content"
    ];
  };

  services.snapper = {
    configs = snapperConfigs;
  };
}
