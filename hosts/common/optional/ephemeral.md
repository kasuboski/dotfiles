# Ephemeral root reset

`ephemeral.nix` recreates disposable Btrfs root before `sysroot.mount`. NixOS
activation reconstructs the system from the selected Nix store generation;
`/nix`, `/persist`, `/home`, and the separate NVMe pool are not reset.

The service waits for `fileSystems."/".device`, not a hardcoded filesystem label.
Its helper is included in the initrd, with no grep/awk pipeline. `findmnt` is
explicitly registered through `boot.initrd.systemd.extraBin`: adding a shell wrapper
to `storePaths` does not automatically include executables named in its PATH.

## Reset and failure behavior

1. Mount the filesystem top level under `/run/btrfs-rollback`.
2. Validate `root-blank` and snapshot it to temporary `root-reset`.
3. Atomically exchange `root-reset` and `root`.
4. Recursively delete the discarded root (including nested subvolumes) now at
   `root-reset`.

There is no retained root backup or snapshot history. A leftover `root-reset` from
an interrupted operation is cleaned up on the next attempt. The atomic exchange
avoids any window where the bootable root path disappears. A missing root left by
the older delete-first implementation is recreated from the blank template.

The oneshot remains active after success and refuses to run once `/sysroot` is
mounted, preventing a retrigger against an already-mounted root.
The reset is wanted, not required, by root mounting. Preparation/exchange failures
are logged, but leave the existing root available for boot. Cleanup failure after
exchange leaves the new root usable. Missing devices, a missing root with no usable
template, or filesystem corruption can still prevent normal mounting.

For a bad configuration, select an older NixOS generation in the boot menu. To
bypass root reset for one boot, append this kernel parameter:

```text
rd.systemd.mask=btrfs-rollback.service
```

This boots the existing root without resetting it. Diagnose errors with:

```bash
sudo journalctl -b -u btrfs-rollback.service
```

## Safe integration test

```bash
nix build path:.#nixosConfigurations.forge.config.system.build.btrfsResetRoot \
  --out-link /tmp/btrfs-reset-root-test
sudo bash scripts/test-btrfs-rollback.sh /tmp/btrfs-reset-root-test/bin/btrfs-reset-root
```

The test formats only a new loop-backed temporary file inside a private mount
namespace. It covers nested subvolumes/spaces, readonly template, minimal PATH,
repeated resets without retained copies, injected snapshot/exchange failures, and
missing-template safety. It never mounts or changes live root.

Before staging a boot, also test the actual packed initrd (not the host store):

```bash
nix build path:.#nixosConfigurations.forge.config.system.build.toplevel \
  --out-link /tmp/forge-rollback-system
nix build path:.#nixosConfigurations.forge.config.system.build.btrfsRollbackInitrdTest \
  --out-link /tmp/forge-rollback-initrd-test
sudo /tmp/forge-rollback-initrd-test/bin/test-btrfs-rollback-initrd \
  /tmp/forge-rollback-system /dev/disk/by-partlabel/disk-main-nixos
```

This unpacks the real initrd, maps ONLY a fresh loop-backed test device to the
configured root-device path, and executes the packed service twice in a private
mount namespace/chroot. No host `/nix` is bound into the chroot. The test covers the
real mount, helper, nested deletion, atomic exchange, cleanup, and persistence.
A fresh marker proves the second reset is not a no-op. Snapshot/exchange failure
injection, missing-template safety, retry and mount cleanup are also checked inside
the packed environment; a missing command or loader/library fails before reboot.
Live boot/device-order validation still requires a separately planned reboot.
