# Backend: restic-rest-server on TrueNAS

Tested on TrueNAS 25.10 with the `restic-rest-server` app from the community
train. The REST backend gives you real append-only repositories, which SFTP
and plain S3 do not.

## 1. Dataset

Storage, Datasets: create `<pool>/backups` (compression `lz4` or off, restic
data is already compressed and encrypted). Note its path, for example
`/mnt/data/backups`.

Create the directory the app will serve and hand it to the app user (uid 568):

```
mkdir -p /mnt/data/backups/restic-server
chown 568:568 /mnt/data/backups/restic-server
chmod 755 /mnt/data/backups/restic-server
```

Repositories will appear as `/mnt/data/backups/restic-server/<user>/<repo>`.

## 2. App

Apps, Discover, `restic-rest-server`, Install:

| Setting | Value |
|---|---|
| Append Only | on |
| Private Repositories | on: each user can only reach `/<user>/...` |
| Users | one username + password **per machine** |
| Storage, Data | Host Path `/mnt/data/backups/restic-server` |
| Additional storage | none needed |
| Port | note it, default 8000, TrueNAS often assigns e.g. 30248 |

Do not use the default ix-volume for Data: it lives under `/mnt/.ix-apps` and
is easy to lose when the app is reinstalled. The client URL becomes

```
rest:http://<nas-ip>:<port>/<user>/<hostname>
```

which `bazzite-backup init` builds for you from the base URL, username and
repository name. One user per machine keeps a compromised laptop from reading
another machine's backups.

Plain HTTP is acceptable on a trusted LAN or over a VPN such as Tailscale:
restic encrypts everything client-side and the basic-auth password only guards
*access*. Put Traefik or the app's own TLS in front for anything else.

## 3. Snapshots of the repositories

Data Protection, Periodic Snapshot Tasks, Add: dataset `<pool>/backups`,
recursive, daily at 03:00, keep 4 weeks. This protects the repositories from
the one thing append-only cannot: a bad prune or damage on the NAS side.

## 4. Pruning

Clients cannot prune. Set up the weekly server-side job in
[../server/README.md](../server/README.md).

## 5. Verify from a client

```
sudo bazzite-backup init --backend rest --rest-url http://<nas-ip>:<port> --rest-user <user>
sudo bazzite-backup run
sudo bazzite-backup restic snapshots
```

On the NAS, `ls /mnt/data/backups/restic-server/<user>/<hostname>` should show
`config data index keys locks snapshots`.
