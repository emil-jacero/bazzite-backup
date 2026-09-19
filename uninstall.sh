#!/usr/bin/bash
# Removes bazzite-backup. Keeps /etc/bazzite-backup (config, secrets, repo password) unless --purge.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
NAME=bazzite-backup
systemctl disable --now $NAME.timer 2>/dev/null || true
rm -f /etc/systemd/system/$NAME.service /etc/systemd/system/$NAME.timer /etc/systemd/system/$NAME-notify.service
rm -rf /etc/systemd/system/$NAME.timer.d /etc/systemd/system/$NAME.service.d
rm -f /usr/local/bin/$NAME
rm -rf /usr/local/share/$NAME /var/cache/$NAME
systemctl daemon-reload
if [[ ${1:-} == --purge ]]; then
  rm -rf "/etc/${NAME:?}" "/var/lib/${NAME:?}"
  echo "removed $NAME including config and repository password"
else
  echo "removed $NAME; kept /etc/$NAME and /var/lib/$NAME (use --purge to delete them)"
fi
