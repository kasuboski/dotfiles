{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  rootDevice = config.fileSystems."/".device;
  rootDeviceUnit = "${utils.escapeSystemdPath rootDevice}.device";
  resetRoot = pkgs.writeShellApplication {
    name = "btrfs-reset-root";
    runtimeInputs = [pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux];
    text = builtins.readFile ./btrfs-reset-root.sh;
  };
in {
  options.local.persistence.docker = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Persist Docker on the system disk (disable when Docker has its own data mount).";
  };

  config = {
    environment.persistence."/persist" = {
      directories =
        [
          "/etc/nixos"
          "/var/lib/nixos"
        ]
        ++ lib.optional config.services.tailscale.enable "/var/lib/tailscale"
        ++ lib.optional config.services.prometheus.enable "/var/lib/${config.services.prometheus.stateDir}"
        ++ lib.optional config.services.grafana.enable config.services.grafana.dataDir
        ++ lib.optional config.services.samba.enable "/var/lib/samba"
        ++ lib.optional (config.virtualisation.docker.enable && config.local.persistence.docker) "/var/lib/docker"
        ++ lib.optional config.virtualisation.incus.enable "/var/lib/incus";
      files = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };

    # Handle machine-id properly with impermanence by symlinking to persistent storage
    environment.etc."machine-id".source = "/persist/etc/machine-id";

    security.sudo.extraConfig = ''
      # rollback results in sudo lectures after each reboot
      Defaults lecture = never
    '';

    system.build.btrfsResetRoot = resetRoot;
    system.build.btrfsRollbackInitrdTest = pkgs.writeShellApplication {
      name = "test-btrfs-rollback-initrd";
      runtimeInputs = with pkgs; [btrfs-progs coreutils dracut gawk gnugrep util-linux];
      text = builtins.readFile ../../../scripts/test-btrfs-rollback-initrd.sh;
    };
    # The initrd copies ELF dependencies, not arbitrary tools named in a shell
    # wrapper's PATH. Register findmnt explicitly; btrfs/coreutils are provided
    # by the Btrfs/initrd modules and verified by the packed-initrd test.
    boot.initrd.systemd.storePaths = [resetRoot];
    boot.initrd.systemd.extraBin.findmnt = lib.getExe' pkgs.util-linux "findmnt";
    boot.initrd.systemd.services.btrfs-rollback = {
      description = "Rollback btrfs root subvolume to blank snapshot";
      # A failed reset leaves root intact; log the failure but allow booting it.
      wantedBy = ["sysroot.mount"];
      before = ["sysroot.mount"];
      after = [rootDeviceUnit];
      requires = [rootDeviceUnit];
      unitConfig = {
        DefaultDependencies = false;
        ConditionPathIsMountPoint = "!/sysroot";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/btrfs-rollback
        mount -t btrfs -o subvolid=5 ${lib.escapeShellArg rootDevice} /run/btrfs-rollback
        trap 'umount /run/btrfs-rollback' EXIT
        ${resetRoot}/bin/btrfs-reset-root /run/btrfs-rollback
      '';
    };
  };
}
