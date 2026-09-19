# Configuration reference

`bazzite-backup init` writes `/etc/bazzite-backup/config`. Edit it by hand or
re-run `init`; the timer picks changes up on the next run. Keys and defaults:

| Key | Default | Meaning |
|---|---|---|
| `BACKEND` | `rest` | `rest` or `s3`, informational |
| `RESTIC_REPOSITORY` | (required) | restic repository URL. Any restic backend works, not only the two `init` knows |
| `HOME_ROOT` | `/var/home` | directory that contains user homes and is a btrfs subvolume |
| `BACKUP_USERS` | `auto` | space-separated user names, or `auto` = every dir in `HOME_ROOT` owned by uid >= 1000 |
| `EXTRA_PATHS` | `/etc` | extra roots, backed up live (not from the snapshot). Consider `/var/lib/libvirt`, `/var/lib/containers` |
| `SNAPPER_CONFIG` | `auto` | snapper config name covering `HOME_ROOT`; `auto` detects; `none` reads the live tree |
| `REACHABILITY_URL` | derived | URL probed before a run; any HTTP status = up. Derived from the repository URL when empty; set to `skip` to disable |
| `PING_URL` | empty | healthchecks.io check URL or ntfy topic URL |
| `PING_KIND` | `auto` | `healthchecks`, `ntfy`, or `auto` (ntfy when the URL contains "ntfy") |
| `NOTIFY_DESKTOP` | `true` | desktop notification to logged-in users on failure |
| `BACKUP_TAG` | `bazzite-backup` | tag on every snapshot |

Secrets in `/etc/bazzite-backup/secrets` (0600): `RESTIC_REST_USERNAME`,
`RESTIC_REST_PASSWORD` for REST; `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
optional `AWS_DEFAULT_REGION` for S3. Any other restic environment variable can
go there too, for example `RESTIC_COMPRESSION=max`.

`/etc/bazzite-backup/repo-password` holds the repository password. Same
password on every machine that shares a repository; different machines with
different repositories can use different passwords.

## Excludes

`/etc/bazzite-backup/excludes`, one restic pattern per line, `#` comments. A
line starting with `~/` is expanded for every backed-up user, so `~/.cache`
becomes `/run/bazzite-backup/home/alice/.cache` and `.../bob/.cache`. Other
lines are passed to restic unchanged. Directories containing a `CACHEDIR.TAG`
are always skipped (`--exclude-caches`), which covers Go, Cargo, pip, and most
browser caches.

The shipped defaults exclude caches, trash, podman storage, Go module cache,
Steam game files and shader caches, `node_modules` and Rust `target` dirs.
Game *saves* and launcher configs stay included.

## Schedule

The timer runs at 00:00 and 12:00 with up to 30 minutes jitter, and catches up
after a missed slot. Change it with a drop-in, not by editing the unit:

```
sudo systemctl edit bazzite-backup.timer
```

```
[Timer]
OnCalendar=
OnCalendar=*-*-* 20:00
```

The service only starts on AC power (`ConditionACPower=true`) and only when
`REACHABILITY_URL` answers. Both are silent skips, not failures.

## Manifests

Each run writes `~/.local/state/bazzite-backup/` for every user:

| File | Rebuild use |
|---|---|
| `rpm-ostree-status.json` | image, layered packages (`requested-packages`) |
| `flatpaks-system.tsv`, `flatpaks-user.tsv` | `flatpak install` list with origins |
| `etc-config-diff.txt` | which `/etc` files differ from the image |
| `enabled-units.txt` | services you enabled |
| `Brewfile` | `brew bundle` if Homebrew is present |

## Multi-user machines

`BACKUP_USERS=auto` picks up every home. All users go into one repository as
one snapshot per run. Restore is per path, so one user's files can be restored
without touching another's. Manifests are written for every user.
