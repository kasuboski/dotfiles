#!/usr/bin/env bash
# Operates only on a mounted Btrfs top level, before sysroot.mount.
set -euo pipefail
if [[ $# != 1 || "$1" == / ]]; then
  echo 'Expected a mounted Btrfs top-level directory, not /.' >&2
  exit 1
fi
top=${1%/}
[[ -n "$top" && "$top" == /* ]]
[[ "$(findmnt -rn -M "$top" -o FSTYPE)" == btrfs ]]
[[ "$(findmnt -rn -M "$top" -o FSROOT)" == / ]]
temporary=$top/root-reset

# Validate the empty template before touching the existing bootable root.
[[ ! -L "$top/root-blank" && ! -L "$top/root" && ! -L "$temporary" ]]
btrfs subvolume show "$top/root-blank" >/dev/null
if [[ ! -e "$top/root" ]]; then
  btrfs subvolume snapshot "$top/root-blank" "$top/root"
fi
btrfs subvolume show "$top/root" >/dev/null
if [[ -e "$temporary" ]]; then
  # Clean up an interrupted reset, not a retained backup/history.
  btrfs subvolume show "$temporary" >/dev/null
  btrfs subvolume delete --recursive "$temporary"
fi
btrfs subvolume snapshot "$top/root-blank" "$temporary"
# Atomic exchange: root always exists, even if replacement fails.
mv --exchange --no-copy -T "$temporary" "$top/root"
btrfs subvolume delete --recursive "$temporary"
echo 'Ephemeral root reset; old root discarded.'
