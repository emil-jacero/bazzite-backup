# bazzite-backup

Scheduled, encrypted, deduplicated backups of user homes on
[Bazzite](https://bazzite.gg) and other Fedora Atomic desktops, using
[restic](https://restic.net) and btrfs snapshots. Targets a restic REST server
(for example on TrueNAS) or any S3-compatible bucket.

It exists because the immutable-desktop story covers the *system* (rpm-ostree
rolls back), but nothing ships for your *data* in `/var/home`.

## What it does

Twice a day, on AC power, when the backend answers:

1. writes rebuild manifests into each user's `~/.local/state/bazzite-backup/`
   (rpm-ostree status, flatpak lists, `/etc` diff, enabled units, Brewfile),
2. takes a read-only snapper snapshot of `/var/home`,
3. bind-mounts it at `/run/bazzite-backup/home` so restic sees stable paths,
4. runs `restic backup` on every user home plus `/etc` (configurable),
5. deletes the snapshot, records success, optionally pings healthchecks.io or ntfy.

Failures raise a desktop notification for logged-in users and a failure ping.

## Quick start

On the machine to back up:

```
git clone https://github.com/emil-jacero/bazzite-backup
cd bazzite-backup
sudo ./install.sh
sudo bazzite-backup init          # asks for backend, credentials, repo password
sudo bazzite-backup run           # first backup
sudo bazzite-backup status
```

Or without a checkout:

```
curl -fsSL https://raw.githubusercontent.com/emil-jacero/bazzite-backup/main/install.sh | sudo bash
sudo bazzite-backup init
```

Before that, prepare a backend:

- [TrueNAS with restic-rest-server](docs/setup-truenas-rest-server.md) (recommended, append-only)
- [S3-compatible storage](docs/setup-s3.md)

Then read [docs/restore.md](docs/restore.md) once, while nothing is on fire.

## Commands

| Command | Purpose |
|---|---|
| `sudo bazzite-backup init [options]` | write config, create snapper config, `restic init`, enable timer. Re-run to change settings. |
| `sudo bazzite-backup run` | back up now |
| `sudo bazzite-backup status` | next run, last result, latest snapshots |
| `sudo bazzite-backup restic <args>` | any restic command against the configured repo, e.g. `snapshots`, `mount`, `restore` |
| `sudo ./uninstall.sh [--purge]` | remove; `--purge` also deletes config and repo password |

`init --yes` with options or `BB_*` environment variables is fully
non-interactive, see [docs/family-machines.md](docs/family-machines.md).

## Files on the machine

| Path | Content |
|---|---|
| `/usr/local/bin/bazzite-backup` | the program |
| `/etc/bazzite-backup/config` | settings ([reference](docs/configuration.md)) |
| `/etc/bazzite-backup/secrets` | backend credentials, mode 0600 |
| `/etc/bazzite-backup/repo-password` | restic repository password, mode 0600 |
| `/etc/bazzite-backup/excludes` | exclude patterns, `~/` expands per user |
| `/etc/systemd/system/bazzite-backup.{service,timer}` | schedule |
| `/var/lib/bazzite-backup/last-{success,failure}` | timestamps for `status` |

Everything lives under `/etc`, `/usr/local` and `/var`, which persist across
rpm-ostree image updates.

## Server side

Append-only means clients never prune. `server/truenas-maintenance.sh` runs
weekly on the server to expire and verify every repository, see
[server/README.md](server/README.md).

## Requirements

restic, snapper, curl, systemd. Bazzite ships all of them (restic on the `-dx`
images; install it with `brew install restic` or layer it otherwise). Works
without snapper or btrfs too, then it reads the live tree.

## License

MIT
