# Backend: S3-compatible storage

Works with AWS S3, Backblaze B2 (S3 API), Cloudflare R2, MinIO, Garage,
SeaweedFS, RustFS and anything else restic's `s3:` backend accepts.

## 1. Bucket and key

Create one bucket for backups and one access key per machine, scoped to a
prefix if the provider supports it (AWS IAM `s3:prefix` conditions, R2 object
prefix scoping, MinIO policies). Repository path convention:

```
s3:https://<endpoint>/<bucket>/<hostname>
```

For AWS the endpoint is `s3.<region>.amazonaws.com`; set `--s3-region` too.

## 2. Client

```
sudo bazzite-backup init --backend s3 \
  --s3-endpoint https://s3.example.com --s3-bucket family-backups \
  --s3-key AKIA... --s3-secret ...  [--s3-region eu-north-1]
```

Or pass the whole URL with `--repo s3:https://...` when the provider uses an
unusual form. The secret can come from `BB_S3_SECRET` instead of the command
line.

## 3. Immutability

S3 has no append-only mode. A key that can write can usually delete. Options,
strongest first:

- Object Lock / versioning with a retention period (AWS, B2, R2, MinIO). Then
  `forget --prune` needs a second, privileged key and runs elsewhere, exactly as
  the server-side job does for REST.
- A key with `PutObject` and `GetObject` but no `DeleteObject`. restic backups
  still work; prune must run with a different key.
- Nothing, and rely on the provider's own versioning to recover.

Configure the reachability check if the endpoint does not answer plain GET on
its root: set `REACHABILITY_URL` in `/etc/bazzite-backup/config` to any URL that
returns an HTTP status when the service is up.

## 4. Pruning

Run `restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune`
from a machine with a privileged key, weekly. `server/truenas-maintenance.sh`
expects local paths and does not apply to S3; a short cron with the same
`forget` line on any host is enough.
