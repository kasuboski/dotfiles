#!/usr/bin/env bash
# Execute the ACTUAL service script inside the unpacked initrd, with no host /nix.
# The only exposed block device is a fresh loop-backed temporary test image.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ $# == 2 ]] || { echo 'Usage: test-btrfs-rollback-initrd SYSTEM ROOT-DEVICE' >&2; exit 1; }
system=$(realpath "$1")
device=$2
[[ -f "$system/initrd" && "$device" == /dev/disk/by-* && "$device" != *..* ]]
if [[ ${BTRFS_INITRD_TEST_NS:-} != 1 ]]; then
  exec unshare --mount --propagation private env BTRFS_INITRD_TEST_NS=1 "$BASH" "$0" "$system" "$device"
fi
work=$(mktemp -d /tmp/btrfs-initrd-test.XXXXXX)
root=$work/initrd
loop=''
cleanup() {
  # Unmount only paths owned by this private test namespace.
  for path in "$root/run/btrfs-rollback" "$root/test-fs" "$root/proc" "$root/dev"; do
    if mountpoint -q "$path"; then umount "$path"; fi
  done
  [[ -z "$loop" ]] || losetup -d "$loop"
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir "$root"
(cd "$root"; lsinitrd --unpack "$system/initrd")
chroot_command=$(command -v chroot)
unit_text=$(env -i PATH=/bin:/sbin "$chroot_command" "$root" /bin/cat /etc/systemd/system/btrfs-rollback.service)
grep -Eq '^RemainAfterExit=(true|yes)$' <<<"$unit_text"
grep -Fxq 'ConditionPathIsMountPoint=!/sysroot' <<<"$unit_text"
[[ -L "$root/etc/systemd/system/sysroot.mount.wants/btrfs-rollback.service" ]]
[[ ! -e "$root/etc/systemd/system/sysroot.mount.requires/btrfs-rollback.service" ]]
start=$(awk -F= '$1=="ExecStart" {sub(/[[:space:]]+$/, "", $2); print $2}' <<<"$unit_text")
[[ "$start" == /nix/store/*/bin/* && -x "$root$start" ]]
grep -Fq -- "$device" "$root$start"

# No /dev bind or /nix bind: the chroot cannot access real host disks/store.
mkdir -p "$root/dev" "$root/proc" "$root/test-fs"
mount -t tmpfs -o mode=755 tmpfs "$root/dev"
mknod -m 666 "$root/dev/null" c 1 3
mount -t proc proc "$root/proc"
truncate -s 256M "$work/disk.img"
loop=$(losetup --find --show "$work/disk.img")
[[ "$loop" == /dev/loop[0-9]* ]]
mkfs.btrfs -q "$loop"
read -r major minor < <(stat -c '%t %T' "$loop")
mkdir -p "$(dirname "$root$device")"
mknod -m 600 "$root$device" b "$((16#$major))" "$((16#$minor))"
mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"

# All fixture creation commands below are the packed initrd executables too.
env -i PATH=/bin:/sbin "$chroot_command" "$root" /bin/sh -eu -c '
  btrfs subvolume create /test-fs/root-blank
  printf template > /test-fs/root-blank/template
  btrfs subvolume snapshot /test-fs/root-blank /test-fs/root
  mkdir -p /test-fs/root/var/lib
  btrfs subvolume create "/test-fs/root/var/lib/child with spaces"
  printf disposable > /test-fs/root/dirty
  btrfs subvolume create /test-fs/home
  printf persistent > /test-fs/home/keep
'
umount "$root/test-fs"

run_packed() {
  # Optional environment assignments inject failures, never host executables.
  local status=0
  env -i PATH=/bin:/sbin "$@" "$chroot_command" "$root" "$start" || status=$?
  if mountpoint -q "$root/run/btrfs-rollback"; then
    echo 'Packed service left its private mount behind.' >&2; exit 1
  fi
  return "$status"
}
printf '\nRunning packed btrfs-rollback.service script without host tools/store...\n'
run_packed

mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"
[[ -f "$root/test-fs/root/template" && ! -e "$root/test-fs/root/dirty" ]]
[[ ! -e "$root/test-fs/root/var/lib/child with spaces" && ! -e "$root/test-fs/root-reset" ]]
[[ -f "$root/test-fs/home/keep" && -f "$root/test-fs/root-blank/template" ]]
printf 'new boot\n' >"$root/test-fs/root/second-boot-marker"
umount "$root/test-fs"
# A successful no-op must not pass the second-boot regression.
run_packed
mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"
[[ ! -e "$root/test-fs/root/second-boot-marker" && ! -e "$root/test-fs/root-reset" ]]
[[ -f "$root/test-fs/root/template" && -f "$root/test-fs/home/keep" ]]
printf 'must survive\n' >"$root/test-fs/root/keep-on-failure"
umount "$root/test-fs"
printf 'PASS: Packed service really resets both boots, with no leftover copies.\n'

for failure in snapshot exchange; do
  expected_status=74
  [[ "$failure" != exchange ]] || expected_status=75
  # Function parameters expand in the packed shell, not the test runner.
  # shellcheck disable=SC2016
  case "$failure" in
    snapshot) injection='BASH_FUNC_btrfs%%=() { if [[ "$1" == subvolume && "$2" == snapshot ]]; then return 74; fi; command btrfs "$@"; }' ;;
    exchange) injection='BASH_FUNC_mv%%=() { return 75; }' ;;
  esac
  if run_packed "$injection"; then
    echo "Packed $failure failure was ignored." >&2; exit 1
  else
    [[ $? == "$expected_status" ]] || { echo 'Packed service failed for the wrong reason.' >&2; exit 1; }
  fi
  mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"
  [[ -f "$root/test-fs/root/keep-on-failure" && -f "$root/test-fs/home/keep" ]]
  umount "$root/test-fs"
  printf 'PASS: Packed %s failure preserves bootable root and persistent data.\n' "$failure"
done
run_packed
mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"
[[ ! -e "$root/test-fs/root/keep-on-failure" && ! -e "$root/test-fs/root-reset" ]]
[[ -f "$root/test-fs/root/template" && -f "$root/test-fs/home/keep" ]]
printf 'keep without template\n' >"$root/test-fs/root/keep-without-template"
env -i PATH=/bin:/sbin "$chroot_command" "$root" /bin/btrfs subvolume delete /test-fs/root-blank
umount "$root/test-fs"
if run_packed; then
  echo 'Packed service accepted a missing template.' >&2; exit 1
fi
mount -t btrfs -o subvolid=5 "$loop" "$root/test-fs"
[[ -f "$root/test-fs/root/keep-without-template" && -f "$root/test-fs/home/keep" ]]
printf 'PASS: Packed retry cleans stale temporary; missing template leaves root intact.\n'
printf 'PASS: No host /nix or host block devices were bound into the test chroot.\n'
