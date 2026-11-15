# Forge NVMe storage migration

**Completed and verified on forge after reboot on 2026-11-15.**
Do not repeat provisioning on the live pool. SATA originals are retained pending
separate cleanup approval; the root-rollback boot issue is a separate follow-up.

## Long-term configuration

- `data-disko.nix`: both NVMe partitions, shared Btrfs profiles/subvolumes, pool mount.
- `storage.nix`: existing-path bind mounts, service mount dependencies, Docker driver,
  Docker persistence opt-out, and monthly scrub.
- `storage-tools.nix`: explicit build-only migration and isolated provisioning outputs.

Normal NixOS rebuilds manage mounts/services; they do not format disks or copy data.
Docker/t3code use `RequiresMountsFor`, with no dependency on migration marker files.
The migration CLI is **not installed** in system packages. Retained scripts/tests
and the reference procedure below are for deliberate recovery/reinstallation only.

## Original migration flow (reference only)

First build the explicit tool and target system as described below. From
**independent SSH/tmux**, run:

```bash
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate run
# After it finishes successfully:
sudo reboot
# After reconnecting:
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate verify
```

`run` performs provisioning, pre-copy, and cutover using
`/home/josh/forge-storage-system`. It asks before erasing the NVMes and before
stopping services. Keep backups and stop other workspace writers before confirming
cutover. It never deletes the SATA originals or reboots automatically. If migration
state already exists, `run` skips provisioning; if a previous cutover was recorded,
it also skips the redundant online pre-copy and goes straight to the final stopped
incremental sync. It will not reformat the pool. A partially failed provisioning still needs inspection:
copying refuses to proceed unless the pool and preparation marker validate.

The SATA system disk remains unchanged. The migration tool provisions ONLY:

- Intel SSDPEKNU020TZ, serial `PHKA3136006P2P0C`
- Crucial CT2000P3PSSD8, serial `2339E8790D45` (destroys the old Windows installation)

The new `forge-data` Btrfs filesystem uses `data=single`, `metadata=raid1`.
File data is NOT redundant: either SSD failing can lose the pool. Checksums and
snapshots are not off-machine backups. `data-disko.nix` is the single declaration
for these devices: one full-size GPT partition on each NVMe, a shared Btrfs
filesystem, and its subvolumes. Forge imports it alongside the SATA declaration.

**Never run unrestricted Disko provisioning against forge's full configuration.**
The migration package evaluates `data-disko.nix` in a separate NixOS configuration
containing ONLY the two NVMes, asserts their exact device paths, and embeds that
configuration's generated `disko-destroy-format-mount` executable. It never derives
provisioning from forge's merged device set or accepts a caller-supplied config.

## Layout

`/srv/forge-data` mounts the filesystem's top level. It contains two sibling
subvolumes: `development` and `docker`. `development` contains ordinary
directories, not nested subvolumes, so one snapshot covers projects and agent state.

| Pool path | Existing path (bind mount) |
| --- | --- |
| development/projects | /home/josh/projects |
| development/t3code | /home/josh/.local/share/t3code |
| development/pi | /home/josh/.pi |
| docker | /var/lib/docker |

Herdr is excluded. Stale Git worktree registrations are not pruned. VM storage is
not provisioned ahead of time; a subvolume can be added later without repartitioning.
No VM service or CoW tuning is enabled.
`/persist`, `/nix`, and the rest of `/home` remain on SATA.

The canonical pool directory is root-private. Existing user-facing bind mounts
retain source ownership/permissions. t3code state contains secrets; protect backups
accordingly. Docker retains `overlay2`, rather than switching Docker storage drivers.
The shared impermanence module's Docker persistence defaults to unchanged on other
hosts; only forge disables its `/persist` bind. Disko generates the canonical pool
mount from the same declaration used to provision it. NixOS manages the bind mounts
and service dependencies; the migration script handles copying/cutover, not layout.

Missing data storage does not intentionally block OS boot (`nofail`), but Docker
and t3code use systemd `RequiresMountsFor` to require their data mounts. The
completed-cutover marker is used only by the recovery tool, not normal startup.
No custom pre-start script is needed; t3code runs as josh.
Do not manually run
agents in the underlying SATA paths if mounts fail: shell tools aren't protected by
system-service dependencies. Diagnose the failure before starting development.

## 1. Build and review, without activating

From this checkout, as josh:

```bash
nix build path:.#nixosConfigurations.forge.config.system.build.forgeStorageMigration \
  --out-link /home/josh/forge-storage-tool
nix build path:.#nixosConfigurations.forge.config.system.build.toplevel \
  --out-link /home/josh/forge-storage-system
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate plan
```

To build and inspect the isolated provisioning executable without executing it:

```bash
nix build path:.#nixosConfigurations.forge.config.system.build.forgeDataDisko \
  --out-link /home/josh/forge-data-disko
# Inspect /home/josh/forge-data-disko/bin/disko-destroy-format-mount.
# Run provisioning ONLY via forge-storage-migrate, not this executable directly.
```

Run the safety/copy tests and inspect the generated provisioning/unit artifacts:

```bash
bash scripts/test-forge-storage-migrate.sh \
  /home/josh/forge-data-disko/bin/disko-destroy-format-mount \
  /home/josh/forge-storage-system
```

Tests use mocks and temporary files; they do not provision or stop services.

These out-links live outside directories being migrated and keep store paths GC-rooted.
Review SSD health, data to erase, mount definitions, and system build before proceeding.
The `plan` command reports SMART data but does not decide whether the SSDs are healthy.
A nonzero SMART exit must be investigated, not bypassed blindly.

Before erasure:

- Explicitly approve destroying both NVMes and confirm no needed Windows data remains.
- Make and verify an independent backup of valuable source data, including uncommitted
  work, t3code's database/WAL/attachments/secrets, Pi state, and Docker named volumes.
- Choose a maintenance window. Stop all editor/agent/build sessions for the final copy.
- Ensure independent SSH access works and credentials do not depend on t3code.
- Review Docker restart policies: manually started containers without restart policies
  will remain stopped after reboot. The configured Ollama unit starts normally.

## 2. Provision and pre-copy

```bash
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate provision
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate precopy
```

Provisioning requires typing both serials at a real terminal. It refuses mounted
devices, swap, active device holders, existing Btrfs on either disk or its partitions,
an existing pool, or existing migration state. It does not modify `/dev/sda`.
After validation/confirmation it invokes the pinned NVMe-only Disko executable,
which creates both GPTs, the shared filesystem, and its subvolumes. Disko temporarily
mounts under `/mnt/forge-data-disko` (the script refuses preexisting mounts or contents
there), never over the live home/Docker paths. The migration tool then unmounts that
location and mounts the pool at its copy staging path. Filesystem creation remains
separate from NixOS activation. The raw Bash source cannot provision: build the
packaged migration tool so the fixed Disko executable is embedded.

The staging mount is `/mnt/forge-data-migration`; it can be remounted by `precopy`
after an interrupted session or reboot. Re-running `precopy` is supported before
cutover. A failed provisioning operation requires inspection: do not delete safety
markers or run `mkfs` again to force progress.

Rsync preserves ownership, permissions, ACLs, xattrs, hard links within each tree,
and sparse files. It does not cross filesystems. Unexpected nested mounts and
nested Btrfs subvolumes are rejected; Docker's live overlay mounts are skipped.
The live pre-copy is deliberately not a consistent application backup. Rsync prints
file-list and transfer progress. Scanning millions of small files still takes time
even with nothing to transfer. Ordinary size/mtime comparisons skip unchanged file
contents; no forced full-content checksum pass is performed.

## 3. Final cutover: independent SSH/tmux only

Do NOT launch this through t3code, a t3code terminal, or one of its agent sessions.
The script rejects processes in the t3code service cgroup, but cannot detect every
indirect launch. Use a normal SSH session, optionally inside an independent tmux.

Stop agents, editors and builds that can write to projects or Pi state. Then:

```bash
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate cutover \
  /home/josh/forge-storage-system
```

The interactive acknowledgement is `CUTOVER`; stop other writers before proceeding.
Backups remain the operator's responsibility.
The script then:

1. Records old/new system paths in `/persist/forge-storage-migration`.
2. Stops t3code, active `docker-*.service` units, all running Docker containers,
   and Docker/socket. Docker's own containerd exits with Docker; a separate
   `containerd.service` is stopped only if it exists. Runtime condition drop-ins block core service
   starts until reboot (unlike runtime masks, these work with NixOS /etc unit links).
3. Performs ordinary incremental rsync using size/mtime comparisons, including
   deletion of destination files removed since pre-copy. Unchanged file contents
   are not reread. Source SATA directories are never deleted or renamed.
4. Runs SQLite `quick_check` against the copied t3code database, including its WAL.
5. Creates the completed-cutover marker and flushes writes.
6. Sets the system profile to the supplied generation and runs
   `switch-to-configuration boot` (NOT `switch`).

**Services remain stopped. Reboot promptly from that SSH session:**

```bash
sudo reboot
```

Do not restart development or Docker on the old boot after final copying: writes
would go to SATA and would not be included in the NVMe copy. Do not reboot into the
new system after a failed/incomplete cutover without inspecting the failure first.
Mount dependencies protect service startup, not interactive user tools. The marker
records migration completion for the recovery tool only.

## 4. Verify after reboot

```bash
sudo /home/josh/forge-storage-tool/bin/forge-storage-migrate verify
```

This checks UUIDs and exact bind roots, pool usage, services, and Docker's driver/data
root, and lists representative linked worktrees. Also manually check:

- This chat and other t3code threads, attachments, credentials, and projects.
- `git status` and worktree operations, especially decisionbench and mono-verde.
- Pi session history and local extensions.
- Docker containers, Ollama models, named volumes and application health.
- `systemctl --failed` and another reboot once comfortable.

The first successful automated verification is NOT permission to delete originals.
Original project/t3code/Pi directories remain underneath the new bind mounts; old
Docker data remains at `/persist/var/lib/docker`. Deleting them needs a separate,
carefully reviewed cleanup operation after independent backups and acceptance.
Never run cleanup against the ordinary home paths while their bind mounts are active.

## Failure recovery and rollback

If `verify` reports that migration is not active after a failed run/reboot, the
canonical pool mount is absent: the migration has not completed, not a reason to
format again. From independent SSH, rerun the updated tool's `run` command; existing
migration state skips provisioning and validates the pool before resuming. A recorded
previous cutover skips another online pre-copy, but still performs the final stopped
incremental sync.

Nothing automatically deletes original data or rolls the machine back. A failed
cutover may leave services stopped/blocked and may have selected the new boot profile.
Inspect the recorded paths and logs before deciding whether to resume or roll back.

Before any new-generation writes, root can select the recorded old system and reboot:

```bash
# Run in an independent root SSH shell; inspect the file/path first.
read -r old < /persist/forge-storage-migration/old-system
test -x "$old/bin/switch-to-configuration"
nix-env --profile /nix/var/nix/profiles/system --set "$old"
"$old/bin/switch-to-configuration" boot
reboot
```

Alternatively, select the old generation in the boot menu. Runtime condition drop-ins
and their blocking marker vanish on reboot. With the old generation, original SATA directories are visible again.

**After any writes on the new system, old data is stale.** A safe rollback then
requires stopping all writers and reverse-syncing the desired state, with backups
of both copies. The migration tool intentionally does not automate this operation.

## Ongoing operations still to configure

Monthly pool scrubbing is declared. Snapshot retention, an external backup target,
SSD TRIM policy, capacity alerts and VM-specific settings require follow-up decisions.
Scrubbing detects bad single-copy data but cannot repair it without another copy.
Snapshots of `development` must be taken at the canonical subvolume; bind mounts
are aliases and must not be independently backed up as additional copies.
