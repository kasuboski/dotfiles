#!/usr/bin/env bash
# Integration test: formats ONLY a freshly allocated loop-backed temporary file.
# Run as root with a built btrfs-reset-root executable.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ $# == 1 ]] || { echo 'Expected a built btrfs-reset-root executable.' >&2; exit 1; }
if [[ ${BTRFS_ROLLBACK_TEST_NS:-} != 1 ]]; then
  exec unshare --mount --propagation private env BTRFS_ROLLBACK_TEST_NS=1 "$BASH" "$0" "$@"
fi
work=$(mktemp -d /tmp/btrfs-rollback-test.XXXXXX)
loop=''
cleanup() {
  mountpoint -q "$work/fs" && umount "$work/fs"
  [[ -z "$loop" ]] || losetup -d "$loop"
  rm -rf -- "$work"
}
trap cleanup EXIT
truncate -s 256M "$work/disk.img"
loop=$(losetup --find --show "$work/disk.img")
[[ "$loop" == /dev/loop[0-9]* ]]
mkfs.btrfs -q "$loop"
mkdir "$work/fs"
mount -t btrfs -o subvolid=5 "$loop" "$work/fs"
top=$work/fs
btrfs subvolume create "$top/root-blank" >/dev/null
printf 'template\n' >"$top/root-blank/template"
btrfs property set -ts "$top/root-blank" ro true
btrfs subvolume snapshot "$top/root-blank" "$top/root" >/dev/null
mkdir -p "$top/root/var/lib"
btrfs subvolume create "$top/root/var/lib/machines" >/dev/null
btrfs subvolume create "$top/root/var/lib/machines/child with spaces" >/dev/null
btrfs subvolume create "$top/root/srv" >/dev/null
printf 'discard\n' >"$top/root/dirty"
btrfs subvolume create "$top/home" >/dev/null
printf 'keep\n' >"$top/home/keep"
btrfs subvolume create "$top/root-other" >/dev/null
printf 'keep\n' >"$top/root-other/keep"
reset=$(realpath "$1")

# Simulate stage 1: the helper supplies its own tools, not the host PATH.
env PATH=/nonexistent "$reset" "$top"
[[ -f "$top/root/template" && ! -e "$top/root/dirty" && ! -e "$top/root/srv" ]]
[[ ! -e "$top/root-reset" && ! -e "$top/root-previous" ]]
[[ -f "$top/root-blank/template" && -f "$top/home/keep" && -f "$top/root-other/keep" ]]
printf 'PASS: Minimal PATH; reset discards nested old root, preserves persistent siblings, and retains no backup\n'
printf 'new boot\n' >"$top/root/latest"
"$reset" "$top"
[[ ! -e "$top/root/latest" && ! -e "$top/root-reset" ]]
printf 'PASS: Repeated reset leaves no old-root copies\n'

printf 'must survive\n' >"$top/root/keep-on-failure"
if (
  # Exported mock is called by the helper's subprocess.
  # shellcheck disable=SC2329
  btrfs() {
    if [[ "$1" == subvolume && "$2" == snapshot ]]; then return 74; fi
    command btrfs "$@"
  }
  export -f btrfs
  "$reset" "$top"
); then
  echo 'Snapshot failure was ignored.' >&2; exit 1
fi
[[ -f "$top/root/keep-on-failure" && -f "$top/home/keep" ]]
printf 'PASS: Snapshot failure leaves current root bootable\n'
if (
  # shellcheck disable=SC2329
  mv() { return 75; }
  export -f mv
  "$reset" "$top"
); then
  echo 'Atomic exchange failure was ignored.' >&2; exit 1
fi
[[ -f "$top/root/keep-on-failure" && -f "$top/root-reset/template" ]]
printf 'PASS: Exchange failure leaves current root bootable\n'
"$reset" "$top"
[[ ! -e "$top/root/keep-on-failure" && ! -e "$top/root-reset" ]]
printf 'PASS: Retry after exchange failure succeeds and discards old root\n'

# Simulate interrupted older code with both a missing root and stale temporary.
btrfs subvolume snapshot "$top/root-blank" "$top/root-reset" >/dev/null
btrfs subvolume delete "$top/root" >/dev/null
"$reset" "$top"
[[ -f "$top/root/template" && ! -e "$top/root-reset" ]]
printf 'PASS: Missing root restored and stale temporary removed\n'
if "$reset" "$top/home"; then
  echo 'Rollback accepted a non-mountpoint.' >&2; exit 1
fi
btrfs subvolume delete "$top/root-blank" >/dev/null
printf 'must survive\n' >"$top/root/keep-on-failure"
if "$reset" "$top"; then
  echo 'Rollback accepted a missing template.' >&2; exit 1
fi
[[ -f "$top/root/keep-on-failure" && -f "$top/home/keep" ]]
printf 'PASS: Invalid mount/template rejected without touching current root\n'
printf 'All disposable Btrfs rollback tests passed. Live root was never mounted or changed.\n'
