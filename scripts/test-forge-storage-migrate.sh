#!/usr/bin/env bash
# Mocked safety checks and temporary-file rsync regression tests only.
# No mounts, service changes, or device writes.
# Mocks/variables are consumed or defined by functions loaded dynamically below.
# shellcheck disable=SC2329,SC2034,SC2154
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script=$script_dir/forge-storage-migrate.sh
generated_disko=${1:-}
built_system=${2:-}
work=$(mktemp -d)
log=$work/log
trap 'rm -rf "$work"' EXIT

bash -n "$script"
shellcheck "$script"
bash "$script" --help >"$log"
grep -q 'NEXT BOOT' "$log"
grep -q 'forge-storage-migrate run' "$log"
if bash "$script" not-a-command >"$log" 2>&1; then
  printf 'Unknown command unexpectedly succeeded\n' >&2
  exit 1
fi

# Load definitions only; never run the CLI dispatch or its root/device checks.
# shellcheck disable=SC1090
source <(awk '/^command=/{exit} {print}' "$script")
expect_fail() {
  local name=$1 expected=$2
  shift 2
  if ("$@") >"$log" 2>&1; then
    printf 'FAIL: %s unexpectedly succeeded\n' "$name" >&2
    exit 1
  fi
  grep -q "$expected" "$log" || { printf 'FAIL: %s failed for wrong reason\n' "$name" >&2; exit 1; }
  printf 'PASS: %s\n' "$name"
}
wrong_stage_uuid() {
  check_pool() { pool_uuid=expected; }
  mkdir() { :; }
  mountpoint() { return 0; }
  findmnt() { printf 'wrong\n'; }
  mount() { die 'Mount must not be called'; }
  mount_stage
}
wrong_stage_root() {
  check_pool() { pool_uuid=expected; }
  mkdir() { :; }
  mountpoint() { return 0; }
  findmnt() {
    case "$*" in *UUID*) printf 'expected\n' ;; *) printf '/wrong-subvolume\n' ;; esac
  }
  mount() { die 'Mount must not be called'; }
  mount_stage
}
mounted_device() {
  lsblk() { printf '/mounted\n'; }
  check_unused
}
missing_data_disko() {
  data_disko=/nonexistent/forge-data-disko
  check_data_disko
}
busy_disko_root() {
  data_disko=$BASH
  findmnt() { printf '%s/srv/forge-data\n' "$disko_root"; }
  check_data_disko
}
fixed_disko_invocation() {
  check_data_disko() { :; }
  data_disko=mock_disko
  mock_disko() {
    [[ $# == 1 && "$1" == --yes-wipe-all-disks ]] || die 'Unexpected Disko arguments.'
    printf 'Mock data-only provisioning invoked\n'
  }
  run_data_disko
}
rsync_test() {
  local mode=$1 rsync_status=$2 count=0
  rsync() {
    count=$((count + 1))
    [[ " $* " != *' --checksum '* ]] || die 'Incremental copy must not reread all contents.'
    return "$rsync_status"
  }
  copy_data "$mode"
  [[ "$count" == 4 ]] || die 'Did not copy all four trees.'
}
incremental_changed_file() {
  local fixture=$work/content-check
  mkdir -p "$fixture/source" "$fixture/stage/development"
  sources=("$fixture/source")
  relative=(development)
  stage=$fixture/stage
  printf 'new content\n' >"$fixture/source/file"
  printf 'old\n' >"$stage/development/file"
  touch -r "$fixture/source/file" "$stage/development/file"
  copy_data stopped
  cmp "$fixture/source/file" "$stage/development/file" || die 'Incremental copy missed a changed file.'
}
optional_containerd_absent() {
  systemctl() {
    if [[ "$1" == show ]]; then
      printf 'not-found\n'
    elif [[ " $* " == *' containerd.service '* ]]; then
      printf 'Failed to stop containerd.service: Unit containerd.service not loaded.\n' >&2
      return 5
    fi
  }
  load_cutover_services
  systemctl stop "${services[@]}"
}
optional_containerd_present() {
  systemctl() { printf 'loaded\n'; }
  load_cutover_services
  [[ " ${services[*]} " == *' containerd.service '* ]] || die 'Loaded containerd must be stopped.'
}
resume_existing_migration() {
  local attempted=${1:-no}
  state=$work/existing-migration-$attempted
  mkdir -p "$state"
  if [[ "$attempted" == yes ]]; then
    touch "$state/new-system"
  fi
  mountpoint() { return 1; }
  self=mock_phase
  mock_phase() {
    [[ "$1" != provision ]] || die 'Resume must never provision again.'
    printf '%s\n' "$1" >>"$work/resume-phases-$attempted"
  }
  system=/nix/store/test-system
  run_migration
  local expected
  if [[ "$attempted" == yes ]]; then
    expected=cutover
  else
    expected=$(printf '%s\n' precopy cutover)
  fi
  [[ "$expected" == "$(<"$work/resume-phases-$attempted")" ]] || die 'Unexpected resume phase sequence.'
}
inactive_verify() {
  mountpoint() { return 1; }
  require_active_pool
}
expect_fail 'Wrong staging UUID' 'Wrong staging filesystem' wrong_stage_uuid
expect_fail 'Wrong staging subvolume' 'not the top-level subvolume' wrong_stage_root
expect_fail 'Mounted disk rejected' 'mounted filesystems or swap' mounted_device
expect_fail 'Invalid target system rejected before migration' 'Expected a built forge NixOS system' check_target_system /nonexistent-forge-system
expect_fail 'Raw script cannot provision' 'Build the packaged migration tool' missing_data_disko
expect_fail 'Busy Disko root rejected' 'refusing recursive unmount' busy_disko_root
(fixed_disko_invocation) >"$log"
printf 'PASS: Fixed Disko executable receives only its confirmation flag\n'
expect_fail 'Final copy rejects vanished files' 'rsync failed (24)' rsync_test stopped 24
expect_fail 'Online copy rejects partial transfer' 'rsync failed (23)' rsync_test online 23
(rsync_test online 24) >"$log"
printf 'PASS: Online copy permits vanished files\n'
(rsync_test stopped 0) >"$log"
printf 'PASS: Final copy visits all four trees\n'
(incremental_changed_file) >"$log"
printf 'PASS: Incremental copy updates changed files without forced checksums\n'
(optional_containerd_absent)
printf 'PASS: Cutover succeeds without a separate containerd unit\n'
(optional_containerd_present)
printf 'PASS: Cutover includes containerd when a separate unit exists\n'
(resume_existing_migration) >"$log"
printf 'PASS: Existing migration resumes without provisioning\n'
(resume_existing_migration yes) >"$log"
printf 'PASS: Attempted cutover resumes without redundant online scan\n'
expect_fail 'Incomplete verification explains safe resume' 'Resume with:' inactive_verify
# Optional built-script audit: inspect the generated code, NEVER execute it.
if [[ -n "$generated_disko" ]]; then
  bash -n "$generated_disko"
  # Disko exports hook variables even when no hook consumes them.
  shellcheck --exclude=SC2034 "$generated_disko"
  expected=$(printf '%s\n' "$intel" "$intel_member" "$crucial" "$crucial_member" | sort)
  actual=$(awk '!/^[[:space:]]*#/' "$generated_disko" | grep -oE '/dev/[[:alnum:]_./:-]+' | grep -v '^/dev/null$' | sort -u)
  [[ "$actual" == "$expected" ]] || die 'Generated Disko script references unexpected devices.'
  grep -Fq 'mkfs.btrfs' "$generated_disko"
  grep -Fq -- '-d single -m raid1' "$generated_disko"
  grep -Fq "$disko_mount" "$generated_disko"
  if grep -Eq '^[[:space:]]*(wipefs|mkfs\.btrfs|btrfs subvolume create)' "$script"; then
    die 'Migration script duplicates Disko formatting/subvolume creation.'
  fi
  printf 'PASS: Generated Disko device allowlist, profiles and isolated mount root\n'
fi
if [[ -n "$built_system" ]]; then
  # Steady-state services rely only on mounts, not one-off migration markers.
  grep -Fxq 'User=josh' "$built_system/etc/systemd/system/t3code.service"
  grep -Fxq 'RequiresMountsFor=/home/josh/projects' "$built_system/etc/systemd/system/t3code.service"
  grep -Fxq 'RequiresMountsFor=/home/josh/.local/share/t3code' "$built_system/etc/systemd/system/t3code.service"
  grep -Fxq 'RequiresMountsFor=/home/josh/.pi' "$built_system/etc/systemd/system/t3code.service"
  grep -Fxq 'RequiresMountsFor=/var/lib/docker' "$built_system/etc/systemd/system/docker.service.d/overrides.conf"
  [[ ! -e "$built_system/sw/bin/forge-storage-migrate" ]] || die 'Migration CLI must not be installed in the system.'
  if grep -Eq 'forge-storage-ready|\.cutover-complete' "$built_system/etc/systemd/system/t3code.service" "$built_system/etc/systemd/system/docker.service.d/overrides.conf"; then
    die 'One-off migration guard remains in steady-state units.'
  fi
  printf 'PASS: Built units use mount dependencies without migration guards or installed CLI\n'
fi
printf 'All migration tests passed. Destructive and reboot paths were NOT executed.\n'
