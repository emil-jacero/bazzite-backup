# Rolling out to several machines

Each machine gets its own REST user (or S3 key) and its own repository named
after the hostname. Repository passwords can differ per machine or be shared;
whatever you choose, store them in a password manager under the hostname.

## Non-interactive install

```
export BB_REST_PASSWORD='the-rest-user-password'
export BB_REPO_PASSWORD='the-repository-password'
curl -fsSL https://raw.githubusercontent.com/emil-jacero/bazzite-backup/main/install.sh | sudo -E bash
sudo -E bazzite-backup init --yes \
  --backend rest --rest-url http://10.0.0.2:30248 --rest-user kid-laptop \
  --ping-url https://hc-ping.com/<uuid> \
  --run-now
```

`sudo -E` passes the `BB_*` variables through. Pin a release with
`BAZZITE_BACKUP_REF=v0.1.0` in front of the curl line. `--yes` fails instead of
prompting when anything is missing, so it is safe in scripts.

Re-running `init` on a configured machine uses the existing values as defaults
and keeps the repository password, so updating a REST password is one command:

```
sudo bazzite-backup init --yes --rest-pass 'new-password'
```

## Monitoring

Family machines fail quietly: closed lids, dead WiFi, a full disk. Give every
machine a `--ping-url`:

- **healthchecks.io**: one check per machine, period 12 h, grace 12 h. Success
  pings the URL, failure pings `<url>/fail`. You get mail when a machine goes
  silent for a day.
- **ntfy**: one topic, success posts at low priority (mute it), failure at high
  priority.

The desktop notification on failure is on by default; turn it off with
`--no-desktop-notify` for machines where the user should not be bothered.

## Updating

```
curl -fsSL https://raw.githubusercontent.com/emil-jacero/bazzite-backup/main/install.sh | sudo bash
```

replaces the program and units, and leaves `/etc/bazzite-backup` alone.

## Snapper on machines that never enabled it

`init` creates a snapper config named `root` for `/var/home` when none exists,
with timeline snapshots off. That is the same config Bazzite's
`ujust configure-snapshots` manages, so enabling hourly snapshots later through
btrfs-assistant just works.
