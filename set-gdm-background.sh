#!/bin/bash
# OPTIONAL: set the GDM (login screen) background on Ubuntu 24.04 / GNOME 46 (Yaru).
# Usage:   sudo bash set-gdm-background.sh /path/to/image.jpg
# Restore: sudo bash set-gdm-background.sh --restore
set -e
GRESOURCE="/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"
BACKUP="${GRESOURCE}.original"
PREFIX="/org/gnome/shell/theme"

if [ "$1" = "--restore" ]; then
  [ -f "$BACKUP" ] || { echo "No backup at $BACKUP"; exit 1; }
  cp "$BACKUP" "$GRESOURCE"; chmod 644 "$GRESOURCE"
  echo "Restored. Run: sudo systemctl restart gdm3 (or reboot)"; exit 0
fi
IMAGE="$1"
[ -z "${IMAGE:-}" ] && { echo "Usage: sudo bash $0 /path/to/image.jpg (or --restore)"; exit 1; }
[ -f "$IMAGE" ] || { echo "Image not found: $IMAGE"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo bash $0 \"$IMAGE\""; exit 1; }

[ -f "$BACKUP" ] || cp "$GRESOURCE" "$BACKUP"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
for res in $(gresource list "$BACKUP"); do
  rel="${res#$PREFIX/}"; mkdir -p "$WORK/$(dirname "$rel")"
  gresource extract "$BACKUP" "$res" > "$WORK/$rel"
done
cp "$IMAGE" "$WORK/gdm-background"
cat >> "$WORK/gdm.css" <<'CSS'
/* --- custom login background --- */
#lockDialogGroup {
  background: url('resource:///org/gnome/shell/theme/gdm-background');
  background-size: cover; background-position: center; background-repeat: no-repeat;
}
CSS
{ echo '<?xml version="1.0" encoding="UTF-8"?>'; echo '<gresources>'; echo "  <gresource prefix=\"$PREFIX\">"
  ( cd "$WORK" && find . -type f | sed 's|^\./||' | sort | while read -r f; do echo "    <file>$f</file>"; done )
  echo '  </gresource>'; echo '</gresources>'; } > "$WORK/t.xml"
( cd "$WORK" && glib-compile-resources t.xml --target=new.gresource )
cp "$WORK/new.gresource" "$GRESOURCE"; chmod 644 "$GRESOURCE"
echo "OK. Apply with: sudo systemctl restart gdm3 (logs you out) or reboot. Undo: sudo bash $0 --restore"
