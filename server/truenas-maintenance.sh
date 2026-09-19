#!/usr/bin/bash
# Weekly forget / prune / check for every restic repository served by a
# restic-rest-server running in append-only mode. Runs ON the server (TrueNAS)
# as root, against the repositories as local paths, so it is not bound by
# append-only. Schedule it away from client backup windows.
#
# usage: truenas-maintenance.sh <repo-root> <password-dir> [restic-binary]
#   repo-root     directory the REST server serves, e.g. /mnt/data/backups/restic-server
#   password-dir  <password-dir>/<user>/<repo> holds the repository password
#                 for <repo-root>/<user>/<repo>; repositories without one are skipped
# env: KEEP_DAILY (14) KEEP_WEEKLY (8) KEEP_MONTHLY (12) CHECK_SUBSET (2%)
set -euo pipefail
ROOT=${1:?repo-root}
PWDIR=${2:?password-dir}
RESTIC=${3:-restic}
KEEP_DAILY=${KEEP_DAILY:-14}
KEEP_WEEKLY=${KEEP_WEEKLY:-8}
KEEP_MONTHLY=${KEEP_MONTHLY:-12}
CHECK_SUBSET=${CHECK_SUBSET:-2%}
export RESTIC_CACHE_DIR=${RESTIC_CACHE_DIR:-/root/.cache/restic}
rc=0

for cfg in "$ROOT"/*/*/config; do
  [[ -f $cfg ]] || continue
  repo=$(dirname "$cfg")
  rel=${repo#"$ROOT"/}
  pw=$PWDIR/$rel
  if [[ ! -r $pw ]]; then
    echo "== $rel: no password file at $pw, skipping"
    continue
  fi
  echo "== $rel"
  export RESTIC_REPOSITORY=$repo RESTIC_PASSWORD_FILE=$pw
  if [[ -n $("$RESTIC" list locks 2>/dev/null) ]]; then
    echo "   locked (a client is probably running), skipping"
    continue
  fi
  if ! "$RESTIC" forget --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" --group-by host,paths --prune; then
    echo "   forget/prune FAILED"; rc=1; continue
  fi
  if ! "$RESTIC" check --read-data-subset="$CHECK_SUBSET"; then
    echo "   check FAILED"; rc=1
  fi
done
exit $rc
