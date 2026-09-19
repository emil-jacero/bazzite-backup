#!/usr/bin/bash
# Installs bazzite-backup. Run from a checkout:   sudo ./install.sh
# or straight from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/emil-jacero/bazzite-backup/main/install.sh | sudo bash
# Set BAZZITE_BACKUP_REF=v0.1.0 to pin a release when piping from curl.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

NAME=bazzite-backup
REPO=emil-jacero/$NAME
REF=${BAZZITE_BACKUP_REF:-main}
SHARE=/usr/local/share/$NAME
SRC=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)

if [[ -z $SRC || ! -x $SRC/bin/$NAME ]]; then
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  echo "downloading $REPO@$REF"
  curl -fsSL "https://github.com/$REPO/archive/$REF.tar.gz" | tar -xz -C "$TMP" --strip-components=1
  SRC=$TMP
fi

install -d -m 0755 "$SHARE" /etc/$NAME /etc/systemd/system
install -m 0755 "$SRC/bin/$NAME" /usr/local/bin/$NAME
install -m 0644 "$SRC/config/config.example" "$SRC/config/secrets.example" "$SRC/config/excludes.example" "$SHARE/"
install -m 0644 "$SRC/systemd/$NAME.service" "$SRC/systemd/$NAME.timer" "$SRC/systemd/$NAME-notify.service" /etc/systemd/system/
restorecon -RF /usr/local/bin/$NAME "$SHARE" /etc/$NAME /etc/systemd/system/$NAME* 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || echo "warning: systemctl unavailable, skipped daemon-reload"

for t in restic snapper curl; do command -v $t >/dev/null || echo "warning: $t not found in PATH"; done
echo "installed $NAME $(/usr/local/bin/$NAME version | awk '{print $2}')"
echo "next: sudo $NAME init"
