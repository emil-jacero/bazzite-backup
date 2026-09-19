# Restore

Read this before you need it. All commands run on the machine doing the restore
and need the repository password.

## Paths inside the repository

Homes are backed up from the bind mount, so a file that lives at
`/var/home/alice/Documents/x.odt` is stored as
`/run/bazzite-backup/home/alice/Documents/x.odt`. Extra paths such as `/etc`
keep their real path.

## One file or folder

Browse:

```
sudo bazzite-backup restic snapshots
sudo mkdir -p /mnt/restic && sudo bazzite-backup restic mount /mnt/restic
# in another terminal: ls /mnt/restic/snapshots/latest/run/bazzite-backup/home/alice/
# Ctrl-C the mount when done
```

Restore into a scratch directory, then copy what you need:

```
sudo bazzite-backup restic restore latest --target /tmp/restore \
  --include '/run/bazzite-backup/home/alice/Documents'
ls /tmp/restore/run/bazzite-backup/home/alice/Documents
```

`latest` can be a snapshot ID from `snapshots`. Add `--host` and `--path`
filters when several machines share a repository.

## A whole home

```
sudo bazzite-backup restic restore latest --target /tmp/restore \
  --include '/run/bazzite-backup/home/alice'
sudo rsync -aHAX --info=progress2 /tmp/restore/run/bazzite-backup/home/alice/ /var/home/alice/
sudo chown -R alice:alice /var/home/alice
```

Log the user out first, or restore into a fresh account.

## Whole machine

1. Install Bazzite from the same image variant (for example `bazzite-dx`). Create
   the same user name.
2. Install bazzite-backup and point it at the **existing** repository with the
   **same** repository password:

   ```
   curl -fsSL https://raw.githubusercontent.com/emil-jacero/bazzite-backup/main/install.sh | sudo bash
   sudo bazzite-backup init --backend rest --rest-url http://<nas>:<port> --rest-user <user> --repo-name <old-hostname>
   ```

   `init` sees the repository is already initialised and does not touch it.
3. Restore the home as above, log out and in again.
4. Rebuild the system from the manifests in `~/.local/state/bazzite-backup/`:

   ```
   cd ~/.local/state/bazzite-backup
   awk -F'\t' 'NR>0 {print $1}' flatpaks-system.tsv | xargs -r flatpak install -y --system
   awk -F'\t' 'NR>0 {print $1}' flatpaks-user.tsv   | xargs -r flatpak install -y --user
   jq -r '.deployments[0]["requested-packages"][]' rpm-ostree-status.json | xargs -r sudo rpm-ostree install
   brew bundle --file=Brewfile        # if you use Homebrew
   cat etc-config-diff.txt            # files to copy back from the restored /etc
   ```

   Files from `/etc` are in the restore at `/tmp/restore/etc/...`; copy back
   the ones the diff lists (network profiles, custom units, fstab entries).
5. Reboot, then run `sudo bazzite-backup run` so the new install has a snapshot.

## Checking the backup without restoring

```
sudo bazzite-backup restic check --read-data-subset=5%
sudo bazzite-backup restic diff <older-id> latest
sudo bazzite-backup restic stats latest
```

Do a real single-file restore every few months. A backup that has never been
restored is a hypothesis.
