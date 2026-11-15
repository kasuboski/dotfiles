#!/usr/bin/env bash
# Build-only recovery tool packaged by hosts/forge/storage-tools.nix.
set -Eeuo pipefail
umask 077

intel=/dev/disk/by-id/nvme-INTEL_SSDPEKNU020TZ_PHKA3136006P2P0C
crucial=/dev/disk/by-id/nvme-CT2000P3PSSD8_2339E8790D45
intel_member=${intel}-part1
crucial_member=${crucial}-part1
# Substituted with a pinned, independently evaluated NVMe-only Disko package.
data_disko=@forgeDataDisko@/bin/disko-destroy-format-mount
disko_root=/mnt/forge-data-disko
disko_mount=$disko_root/srv/forge-data
stage=/mnt/forge-data-migration
pool=/srv/forge-data
state=/persist/forge-storage-migration
sources=(/home/josh/projects /home/josh/.local/share/t3code /home/josh/.pi /persist/var/lib/docker)
relative=(development/projects development/t3code development/pi docker)
targets=(/home/josh/projects /home/josh/.local/share/t3code /home/josh/.pi /var/lib/docker)

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'forge-storage-migrate run [system-path]  # provision, precopy, cutover; default ~/forge-storage-system' \
    'forge-storage-migrate plan' \
    'forge-storage-migrate provision   # interactive; erases ONLY the two specified NVMes' \
    'forge-storage-migrate precopy     # online, NOT a consistent backup' \
    'forge-storage-migrate cutover /nix/store/...-nixos-system-forge-...' \
    'forge-storage-migrate verify      # after reboot' \
    '' \
    'Cutover stops t3code/Docker and selects the supplied system for NEXT BOOT.' \
    'Run it from independent SSH/tmux, with all agents and workspace writers stopped.' \
    'Provisioning invokes ONLY the packaged NVMe-only Disko entry point.' \
    'It does not reboot or delete original SATA data.'
}
confirm() {
  local answer
  printf '\n%s\nType exactly: %s\n> ' "$1" "$2" >/dev/tty
  read -r answer </dev/tty
  [[ "$answer" == "$2" ]] || die 'Confirmation did not match.'
}
check_devices() {
  local device expected actual
  [[ -b "$intel" && -b "$crucial" ]] || die 'Expected NVMe devices missing.'
  [[ "$(readlink -f "$intel")" != "$(readlink -f "$crucial")" ]] || die 'Devices alias each other.'
  for device in "$intel" "$crucial"; do
    case "$device" in
      "$intel") expected=PHKA3136006P2P0C ;;
      "$crucial") expected=2339E8790D45 ;;
    esac
    actual=$(lsblk -dn -o SERIAL "$device" | tr -d '[:space:]')
    [[ "$actual" == "$expected" ]] || die "Serial mismatch: $device"
    [[ "$(lsblk -dn -o TYPE "$device")" == disk ]] || die 'Expected whole disks.'
  done
}
check_unused() {
  local device node
  for device in "$intel" "$crucial"; do
    [[ -z "$(lsblk -nr -o MOUNTPOINTS "$device" | tr -d '[:space:]')" ]] || die "$device has mounted filesystems or swap."
    while read -r node; do
      [[ -z "$(ls -A "/sys/class/block/$(basename "$node")/holders")" ]] || die "$node has active holders."
    done < <(lsblk -nrpo NAME "$device")
  done
}
check_pool() {
  local uuid other
  check_devices
  [[ -b "$intel_member" && -b "$crucial_member" ]] || die 'Expected NVMe member partitions missing.'
  uuid=$(blkid -s UUID -o value "$intel_member")
  other=$(blkid -s UUID -o value "$crucial_member")
  [[ -n "$uuid" && "$uuid" == "$other" ]] || die 'NVMe filesystem UUIDs do not match.'
  [[ "$(blkid -s TYPE -o value "$intel_member")" == btrfs ]] || die 'Expected Btrfs.'
  [[ "$(blkid -s LABEL -o value "$intel_member")" == forge-data ]] || die 'Unexpected pool label.'
  pool_uuid=$uuid
}
check_data_disko() {
  [[ -x "$data_disko" ]] || die 'Build the packaged migration tool; raw script cannot provision.'
  [[ ! -L "$disko_root" ]] || die 'Disko staging root must not be a symlink.'
  [[ "$(findmnt -rn -o TARGET | awk -v p="$disko_root" '$0==p || index($0,p"/")==1 {n++} END {print n+0}')" == 0 ]] || die 'Disko staging root has mounts; refusing recursive unmount.'
  [[ ! -d "$disko_root" || -z "$(ls -A "$disko_root")" ]] || die 'Disko staging root is not empty.'
}
run_data_disko() {
  check_data_disko
  # Our serial confirmation has already run. This script's device set is
  # asserted at Nix evaluation time; no caller-supplied flake/config is accepted.
  "$data_disko" --yes-wipe-all-disks
}
mount_stage() {
  check_pool
  mkdir -p "$stage"
  if ! mountpoint -q "$stage"; then
    mount -t btrfs -o subvolid=5,compress=zstd,noatime "$intel_member" "$stage"
  fi
  [[ "$(findmnt -rn -M "$stage" -o UUID)" == "$pool_uuid" ]] || die 'Wrong staging filesystem.'
  [[ "$(findmnt -rn -M "$stage" -o FSROOT)" == / ]] || die 'Staging mount is not the top-level subvolume.'
  [[ -f "$stage/.forge-storage-prepared" ]] || die 'Pool was not prepared by this script.'
  btrfs filesystem usage "$stage" | grep -q 'Data,single:' || die 'Expected data=single.'
  btrfs filesystem usage "$stage" | grep -q 'Metadata,RAID1:' || die 'Expected metadata=raid1.'
  local name
  for name in development docker; do
    btrfs subvolume show "$stage/$name" >/dev/null
  done
}
check_originals() {
  local source root_uuid
  root_uuid=$(findmnt -rn -T /home/josh -o UUID)
  [[ -n "$root_uuid" && "$root_uuid" != "$pool_uuid" ]] || die 'Home is already on the pool.'
  for source in "${sources[@]}"; do
    [[ -d "$source" && ! -L "$source" ]] || die "Missing or symlinked source: $source"
    [[ "$(findmnt -rn -T "$source" -o UUID)" == "$root_uuid" ]] || die "Source is not on original home filesystem: $source"
    # Nested mounts/subvolumes need explicit migration rules; do not silently skip.
    [[ "$(findmnt -rn -o TARGET,FSTYPE | awk -v p="$source/" '
      index($1,p)==1 {
        if (p=="/persist/var/lib/docker/" && $2=="overlay" && $1 ~ /\/overlay2\/[^/]+\/merged$/) next
        n++
      } END {print n+0}')" == 0 ]] || die "Unexpected nested mounts under $source; inspect them first."
    [[ -z "$(btrfs subvolume list -o "$source")" ]] || die "Nested subvolumes under $source need explicit handling."
  done
  [[ "$(findmnt -rn -T /var/lib/docker -o UUID)" == "$root_uuid" ]] || die 'Docker is not on the original filesystem.'
}
copy_data() {
  local mode=$1 i result
  # Ordinary incremental rsync: unchanged size/mtime files are not reread.
  # Cutover stops Docker/t3code before this final synchronization.
  for i in "${!sources[@]}"; do
    printf '\nScanning/syncing %s -> %s/%s\n' "${sources[$i]}" "$stage" "${relative[$i]}"
    result=0
    rsync -aHAXSx --numeric-ids --delete-delay --info=progress2,stats2,flist2 --outbuf=L \
      "${sources[$i]}/" "$stage/${relative[$i]}/" || result=$?
    if [[ "$result" != 0 ]]; then
      [[ "$mode" == online && "$result" == 24 ]] || die "rsync failed ($result); originals retained."
      printf 'Online copy saw vanished files; final stopped copy is still required.\n'
    fi
  done
}

load_cutover_services() {
  services=(t3code.service docker.service docker.socket)
  # NixOS Docker normally starts its own containerd, without a systemd unit.
  # Stopping Docker handles that process; only stop a separate unit if present.
  local load_state
  load_state=$(systemctl show containerd.service -p LoadState --value)
  if [[ "$load_state" != not-found ]]; then
    services+=(containerd.service)
  fi
}

run_migration() {
  if mountpoint -q "$pool"; then
    "$self" verify
    return
  fi
  if [[ -e "$state" ]]; then
    printf 'Existing migration found; resuming copies/cutover without provisioning.\n'
  else
    "$self" provision
  fi
  # new-system is recorded only after the initial online copies succeeded and
  # cutover was confirmed. A retry needs only the final stopped incremental sync.
  if [[ ! -f "$state/new-system" ]]; then
    "$self" precopy
  else
    printf 'Previous cutover attempt found; skipping redundant online scan.\n'
  fi
  "$self" cutover "$system"
}

require_active_pool() {
  if ! mountpoint -q "$pool"; then
    die "Migration is not active: $pool is not mounted. Cutover did not complete or the new generation is not active. Resume with: sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate run (from SSH). Do not run provision again."
  fi
}

cutover_failed() {
  printf 'Cutover failed at line %s: %s (exit %s). Services may remain stopped. Do NOT delete either copy.\n' "$2" "$3" "$1" >&2
}

check_independent_session() {
  if grep -q 't3code.service' /proc/self/cgroup; then
    die 'Do not run migration from t3code. Use independent SSH/tmux.'
  fi
}
check_target_system() {
  system=$(readlink -f "$1")
  [[ "$system" == /nix/store/*-nixos-system-forge-* && -x "$system/bin/switch-to-configuration" ]] || die 'Expected a built forge NixOS system store path.'
  grep -q 'forge-data' "$system/etc/fstab" || die 'Target system lacks pool mounts.'
  local target
  for target in "${targets[@]}"; do
    grep -Fq "$target" "$system/etc/fstab" || die "Target system lacks mount $target"
  done
}

command=${1:-help}
case "$command" in help|--help|-h) usage; exit 0 ;; esac
[[ "$command" =~ ^(run|plan|provision|precopy|cutover|verify)$ ]] || { usage; exit 1; }
[[ "$EUID" == 0 ]] || die 'Run as root.'
[[ "$(hostname -s)" == forge ]] || die 'This tool is only for forge.'
if [[ "$command" == run ]]; then
  [[ $# -le 2 ]] || die 'Usage: forge-storage-migrate run [system-path]'
  check_independent_session
  check_target_system "${2:-/home/josh/forge-storage-system}"
  self=$(readlink -f "$0")
  # Each phase takes its own lock and keeps its existing safety confirmations.
  run_migration
  exit
fi
cd /
exec 9>/run/lock/forge-storage-migrate.lock
flock -n 9 || die 'Another migration command is running.'
check_devices

case "$command" in
  plan)
    lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS "$intel" "$crucial"
    printf '\nNVMe health (review all warnings before provisioning):\n'
    smartctl -a "$intel"
    smartctl -a "$crucial"
    printf '\nPlanned sources (no data changed):\n'
    printf '%s\n' "${sources[@]}"
    ;;
  provision)
    [[ $# == 1 ]] || die 'Unexpected arguments.'
    check_unused
    ! mountpoint -q "$stage" || die 'Staging path is already mounted.'
    [[ ! -d "$stage" || -z "$(ls -A "$stage")" ]] || die 'Staging path is not empty.'
    [[ ! -e /dev/disk/by-label/forge-data ]] || die 'forge-data already exists; refusing to format.'
    [[ ! -e "$state" ]] || die 'Migration state exists; inspect it before provisioning.'
    for device in "$intel" "$crucial"; do
      while read -r node; do
        [[ "$(blkid -s TYPE -o value "$node" || true)" != btrfs ]] || die 'Existing Btrfs detected; refusing to overwrite.'
      done < <(lsblk -nrpo NAME "$device")
    done
    check_data_disko
    confirm 'This destroys ALL data on BOTH NVMes, including Windows. Confirm SSD health and external backups first.' \
      'ERASE PHKA3136006P2P0C 2339E8790D45'
    check_unused
    mkdir -m 700 "$state"
    lsblk -o NAME,PATH,SIZE,SERIAL,FSTYPE,UUID "$intel" "$crucial" >"$state/before.txt"
    run_data_disko
    check_pool
    [[ "$(findmnt -rn -M "$disko_mount" -o UUID)" == "$pool_uuid" ]] || die 'Wrong filesystem mounted by Disko.'
    umount "$disko_mount"
    rmdir "$disko_mount" "$disko_root/srv" "$disko_root"
    mkdir -p "$stage"
    mount -t btrfs -o subvolid=5,compress=zstd,noatime "$intel_member" "$stage"
    chmod 700 "$stage"
    mkdir -p "$stage/development/"{projects,t3code,pi}
    chmod 700 "$stage/development"
    touch "$stage/.forge-storage-prepared"
    mount_stage
    printf 'Pool prepared. Run precopy next. Original SATA data is unchanged.\n'
    ;;
  precopy)
    [[ $# == 1 ]] || die 'Unexpected arguments.'
    mount_stage
    [[ ! -e "$stage/.cutover-complete" ]] || die 'Cutover already staged; refusing to overwrite.'
    check_originals
    copy_data online
    ;;
  cutover)
    [[ $# == 2 ]] || die 'Supply the prebuilt NixOS system store path.'
    check_independent_session
    check_target_system "$2"
    load_cutover_services
    mount_stage
    [[ ! -e "$stage/.cutover-complete" ]] || die 'Cutover already staged; inspect state instead of rerunning.'
    check_originals
    confirm 'All agents/editors/builds must be stopped. This stops t3code, Docker and its containers. Run from independent SSH/tmux. Originals stay in place for rollback.' \
      'CUTOVER'
    mkdir -p "$state"
    chmod 700 "$state"
    readlink -f /nix/var/nix/profiles/system >"$state/old-system"
    printf '%s\n' "$system" >"$state/new-system"
    # No automatic service restart on failure: a partially completed cutover
    # needs operator inspection, not concurrent writes to either copy.
    trap 'cutover_failed "$?" "$LINENO" "$BASH_COMMAND"' ERR
    systemctl stop t3code.service
    systemctl list-units --state=active --plain --no-legend 'docker-*.service' | awk '{print $1}' >"$state/docker-units"
    while read -r unit; do
      [[ -z "$unit" ]] || systemctl stop "$unit"
    done <"$state/docker-units"
    if systemctl is-active --quiet docker.service; then
      docker ps -q | xargs -r docker stop
    fi
    # /etc unit links on NixOS take precedence over /run unit masks. Unique
    # runtime drop-ins instead prevent socket/timer/manual activation races.
    touch /run/forge-storage-cutover
    for unit in "${services[@]}"; do
      mkdir -p "/run/systemd/system/$unit.d"
      printf '[Unit]\nConditionPathExists=!/run/forge-storage-cutover\n' \
        >"/run/systemd/system/$unit.d/forge-storage-cutover.conf"
    done
    systemctl daemon-reload
    systemctl stop "${services[@]}"
    for unit in "${services[@]}"; do
      if systemctl is-active --quiet "$unit"; then
        die "$unit is still running; final copy is unsafe."
      fi
    done
    check_originals
    copy_data stopped
    [[ "$(sqlite3 -readonly "$stage/development/t3code/userdata/statev2.sqlite" 'PRAGMA quick_check;')" == ok ]] || die 'Copied t3code database failed quick_check.'
    touch "$stage/.cutover-complete"
    sync
    nix-env --profile /nix/var/nix/profiles/system --set "$system"
    "$system/bin/switch-to-configuration" boot
    trap - ERR
    printf '\nCutover staged for next boot. Services remain STOPPED. Reboot now from this SSH session.\n'
    printf 'Do not restart agents or Docker before reboot; SATA originals would diverge.\n'
    printf 'After reboot: sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate verify\n'
    ;;
  verify)
    [[ $# == 1 ]] || die 'Unexpected arguments.'
    check_pool
    require_active_pool
    [[ "$(findmnt -rn -M "$pool" -o UUID)" == "$pool_uuid" ]] || die 'Wrong canonical filesystem.'
    [[ -f "$pool/.cutover-complete" ]] || die 'Cutover marker missing.'
    for i in "${!targets[@]}"; do
      target=${targets[$i]}
      mountpoint -q "$target" || die "Missing bind mount: $target"
      [[ "$(findmnt -rn -M "$target" -o UUID)" == "$pool_uuid" ]] || die "Wrong filesystem at $target"
      [[ "$(findmnt -rn -M "$target" -o FSROOT)" == "/${relative[$i]}" ]] || die "Wrong bind source at $target"
      findmnt -M "$target"
    done
    btrfs filesystem usage "$pool"
    systemctl is-active t3code.service docker.service
    [[ "$(docker info --format '{{.Driver}}')" == overlay2 ]] || die 'Docker driver changed.'
    [[ "$(docker info --format '{{.DockerRootDir}}')" == /var/lib/docker ]] || die 'Unexpected Docker data root.'
    runuser -u josh -- git -C /home/josh/projects/decisionbench worktree list
    runuser -u josh -- git -C /home/josh/projects/mono-verde worktree list
    printf '\nMounts and service checks passed. Check chats, worktrees, containers and volumes manually.\n'
    printf 'Original SATA directories still exist beneath the bind mounts; nothing was deleted.\n'
    ;;
esac
