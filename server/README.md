# Server-side maintenance

Clients back up to a `restic-rest-server` running in **append-only** mode, so they
cannot delete or prune anything, which is the point: a compromised laptop cannot
destroy its own history. Something still has to expire old snapshots and verify
the repositories. That runs on the server, where the repositories are plain
directories.

`truenas-maintenance.sh` walks `<repo-root>/<user>/<repo>`, and for each
repository that has a password file at `<password-dir>/<user>/<repo>`:

1. skips it if a restic lock exists (a client is mid-backup),
2. `restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune`,
3. `restic check --read-data-subset=2%`.

Repositories without a password file are listed and skipped, so adding a
machine never silently enrols it into pruning. After each repository the script
chowns it back to the owner of the repo root (uid 568 on TrueNAS), because
files written by root would otherwise be unreadable for the REST server.

## Deleting a specific snapshot

Clients cannot delete. On the server, with the password file in place:

```
R=/mnt/data/backups/restic-server/<user>/<repo>
restic -r $R -p /root/.config/bazzite-backup/passwords/<user>/<repo> forget <snapshot-id> --prune
chown -R 568:568 $R
```

## Setup on TrueNAS (25.10 or later)

TrueNAS ships restic at `/usr/bin/restic` (used by its own cloud backup
feature). Using it directly is unsupported by iX but works; the repository
format is compatible with current restic clients.

1. Copy the script somewhere on a data pool, not the boot pool:

   ```
   mkdir -p /mnt/data/scripts /root/.config/bazzite-backup/passwords
   cp truenas-maintenance.sh /mnt/data/scripts/
   chmod 700 /mnt/data/scripts/truenas-maintenance.sh
   ```

2. For each client repository, store its repository password:

   ```
   mkdir -p /root/.config/bazzite-backup/passwords/<user>
   printf '%s\n' 'the-repo-password' > /root/.config/bazzite-backup/passwords/<user>/<repo>
   chmod 600 /root/.config/bazzite-backup/passwords/<user>/<repo>
   ```

   The path mirrors the repository path under the REST server root.

3. System Settings, Advanced, Cron Jobs, Add:

   | Field       | Value |
   |-------------|-------|
   | Command     | `/mnt/data/scripts/truenas-maintenance.sh /mnt/data/backups/restic-server /root/.config/bazzite-backup/passwords /usr/bin/restic` |
   | Run as user | root |
   | Schedule    | weekly, e.g. Sunday 04:00, outside the clients' backup windows (default 00:00 and 12:00) |
   | Hide stderr | off, so failures show in the job log |

Retention can be tuned with the environment variables `KEEP_DAILY`,
`KEEP_WEEKLY`, `KEEP_MONTHLY` and `CHECK_SUBSET`, for example by prefixing the
command with `KEEP_MONTHLY=24`.

## Also protect the dataset itself

Prune is a delete. Take ZFS snapshots of the dataset that holds the repositories
so a bad prune, a bug, or ransomware on the NAS can be rolled back:
Data Protection, Periodic Snapshot Tasks, dataset `data/backups`, recursive,
daily, keep 4 weeks. See [../docs/setup-truenas-rest-server.md](../docs/setup-truenas-rest-server.md).
