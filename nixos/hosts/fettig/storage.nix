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
  snapraidDataDisks = builtins.listToAttrs (lib.lists.imap0 (i: d: {
      name = "d${toString i}";
      value = "/mnt/${d.name}";
    })
    dataDisks);
  contentFiles =
    [
      "/persist/var/snapraid.content"
    ]
    ++ builtins.map (d: "/mnt/snapraid-content/${d.name}/snapraid.content") dataDisks;
  parityFiles = builtins.map (p: "/mnt/${p.name}/snapraid.parity") parityDisks;
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
    snapraid-btrfs
    snapraid-btrfs-runner
  ];

  fileSystems =
    {
      "/mnt/speicher" = {
        device = "192.168.86.120:/speicher";
        fsType = "nfs";
        options = ["x-systemd.automount" "noauto"];
      };
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
    inherit contentFiles parityFiles;
    enable = true;
    sync.interval = "";
    scrub.interval = "";
    dataDisks = snapraidDataDisks;
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

  # environment.persistence."/persist" = {
  #   files = [
  #     "/var/snapraid.content"
  #   ];
  # };

  services.snapper = {
    configs = snapperConfigs;
  };

  systemd.services.snapraid-btrfs-sync = {
    description = "Run the snapraid-btrfs sync with the runner";
    startAt = "01:00";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.snapraid-btrfs-runner}/bin/snapraid-btrfs-runner";
      Nice = 19;
      IOSchedulingPriority = 7;
      CPUSchedulingPolicy = "batch";

      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = "AF_UNIX";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = "@system-service";
      SystemCallErrorNumber = "EPERM";
      CapabilityBoundingSet = "";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadOnlyPaths = ["/etc/snapraid.conf" "/etc/snapper"];
      ReadWritePaths =
        # sync requires access to directories containing content files
        # to remove them if they are stale
        let
          contentDirs = builtins.map builtins.dirOf contentFiles;
        in
          lib.unique (
            builtins.attrValues snapraidDataDisks ++ parityFiles ++ contentDirs
          );
    };
  };
}
