#!/usr/bin/env bash
###############################################################################
#  macOS look for Ubuntu 24.04 / GNOME 46 (Wayland)
#  Reproduces the full setup: WhiteSur theme/icons/cursor, Inter font,
#  Dash-to-Dock (dark translucent), macOS Launchpad icon, traffic-light buttons,
#  clock top-right, no-overview-at-login, Ventura wallpaper + lock screen.
#
#  Run on a FRESH Ubuntu 24.04 GNOME install:
#      bash install-macos-look.sh
#  Then LOG OUT and back in (extensions load on a fresh session).
#
#  NOTE: dock/panel glass-blur (Blur my Shell) is intentionally NOT used —
#  it was unreliable (white bar at login / square corners). The dock uses a
#  hard-coded dark translucent color instead, which is stable.
###############################################################################
set -euo pipefail

SHELL_VER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
echo ">>> GNOME Shell $SHELL_VER detected"
USER_ICONS="$HOME/.local/share/icons"
USER_EXT="$HOME/.local/share/gnome-shell/extensions"
SRC="$HOME/.local/src"
WALL="$HOME/Pictures/Wallpapers"
mkdir -p "$SRC" "$WALL" "$HOME/.local/share/fonts/Inter"

#------------------------------------------------------------------ 1. deps
echo ">>> [1/8] Installing apt dependencies (needs sudo)…"
sudo apt-get update -y
sudo apt-get install -y git curl unzip sassc libxml2-utils libglib2.0-dev-bin \
    gnome-tweaks gnome-shell-extension-manager gnome-screenshot fontconfig

#------------------------------------------------------------------ 2. WhiteSur theme/icons/cursor/wallpapers
echo ">>> [2/8] Installing WhiteSur theme, icons, cursor, wallpapers…"
cd "$SRC"
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2"; }
clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git   WhiteSur-gtk-theme
clone https://github.com/vinceliuice/WhiteSur-icon-theme.git  WhiteSur-icon-theme
clone https://github.com/vinceliuice/WhiteSur-cursors.git     WhiteSur-cursors
clone https://github.com/vinceliuice/WhiteSur-wallpapers.git  WhiteSur-wallpapers
( cd WhiteSur-gtk-theme  && ./install.sh -c Dark -t blue )
( cd WhiteSur-icon-theme && ./install.sh -t default )
( cd WhiteSur-cursors    && ./install.sh )
cp WhiteSur-wallpapers/4k/*.jpg "$WALL/" 2>/dev/null || true

#------------------------------------------------------------------ 3. Inter font
echo ">>> [3/8] Installing Inter font…"
curl -fsSL -o /tmp/inter.zip https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip
rm -rf /tmp/inter_x && unzip -o -q /tmp/inter.zip -d /tmp/inter_x
find /tmp/inter_x -iname "Inter*.ttf" -exec cp {} "$HOME/.local/share/fonts/Inter/" \; 2>/dev/null || true
fc-cache -f >/dev/null 2>&1

#------------------------------------------------------------------ 4. GNOME extensions
echo ">>> [4/8] Installing GNOME extensions…"
install_ext() {
  local uuid="$1"
  curl -fsSL -o "/tmp/$uuid.zip" \
    "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${SHELL_VER}" \
    && gnome-extensions install --force "/tmp/$uuid.zip" \
    && echo "    installed $uuid" || echo "    !! $uuid not available for shell $SHELL_VER"
}
install_ext "dash-to-dock@micxgx.gmail.com"
install_ext "no-overview@fthx"
install_ext "Move_Clock@rmy.pobox.com"
install_ext "user-theme@gnome-shell-extensions.gcampax.github.com"

# helper: set a key on an extension's bundled schema (works before the ext is loaded)
extset() { local uuid="$1"; shift; GSETTINGS_SCHEMA_DIR="$USER_EXT/$uuid/schemas" gsettings set "$@"; }
glib-compile-schemas "$USER_EXT/user-theme@gnome-shell-extensions.gcampax.github.com/schemas" 2>/dev/null || true

#------------------------------------------------------------------ 5. macOS Launchpad icon + dash-to-dock patch
echo ">>> [5/8] Installing Launchpad icon + patching Dash-to-Dock…"
LP="$USER_ICONS/WhiteSur/apps/scalable/launchpad-macos.svg"
mkdir -p "$(dirname "$LP")"
cat > "$LP" <<'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fdfdff"/><stop offset="1" stop-color="#dfe1e6"/></linearGradient></defs>
  <rect x="112" y="112" width="800" height="800" rx="184" fill="url(#s)"/>
  <g>
    <rect x="300" y="300" width="128" height="128" rx="34" fill="#ff6b60"/>
    <rect x="448" y="300" width="128" height="128" rx="34" fill="#ffcd49"/>
    <rect x="596" y="300" width="128" height="128" rx="34" fill="#4cd964"/>
    <rect x="300" y="448" width="128" height="128" rx="34" fill="#5ac8fa"/>
    <rect x="448" y="448" width="128" height="128" rx="34" fill="#a78bfa"/>
    <rect x="596" y="448" width="128" height="128" rx="34" fill="#0a84ff"/>
    <rect x="300" y="596" width="128" height="128" rx="34" fill="#ff9f0a"/>
    <rect x="448" y="596" width="128" height="128" rx="34" fill="#ff6482"/>
    <rect x="596" y="596" width="128" height="128" rx="34" fill="#64d2ff"/>
  </g>
</svg>
SVG
# point the dock's show-apps button at the icon by absolute path (bypasses theme lookup)
D2D="$USER_EXT/dash-to-dock@micxgx.gmail.com/appIcons.js"
if [ -f "$D2D" ] && ! grep -q "launchpad-macos.svg" "$D2D"; then
  sed -i "s|^\([[:space:]]*\)this\._iconActor\.iconName = .view-app-grid.*|\1this._iconActor.gicon = Gio.icon_new_for_string('$LP');|" "$D2D"
fi

#------------------------------------------------------------------ 6. dark translucent top bar (theme CSS)
echo ">>> [6/8] Theming the top bar (dark translucent)…"
CSS="$HOME/.themes/WhiteSur-Dark-blue/gnome-shell/gnome-shell.css"
if [ -f "$CSS" ] && ! grep -q "MACOS-PANEL-START" "$CSS"; then
cat >> "$CSS" <<'PANELCSS'
/* MACOS-PANEL-START */
#panel { background-color: rgba(28,28,30,0.82) !important;
         background-gradient-start: rgba(28,28,30,0.82) !important;
         background-gradient-end: rgba(28,28,30,0.82) !important; }
#panel:overview { background-color: transparent !important; }
/* MACOS-PANEL-END */
PANELCSS
fi

#------------------------------------------------------------------ 7. apply all settings
echo ">>> [7/8] Applying settings…"
IFACE=org.gnome.desktop.interface
gsettings set $IFACE color-scheme 'prefer-dark'
gsettings set $IFACE gtk-theme 'WhiteSur-Dark-blue'
gsettings set $IFACE icon-theme 'WhiteSur'
gsettings set $IFACE cursor-theme 'WhiteSur-cursors'
gsettings set $IFACE font-name 'Inter 11'
gsettings set $IFACE document-font-name 'Inter 11'
gsettings set $IFACE enable-hot-corners false
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Semi-Bold 11'

# shell theme (via user-theme bundled schema, then dconf so it persists)
extset "user-theme@gnome-shell-extensions.gcampax.github.com" org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark-blue' 2>/dev/null || true
dconf write /org/gnome/shell/extensions/user-theme/name "'WhiteSur-Dark-blue'"

# Dash-to-Dock (dark translucent, rounded, bottom, always-on)  — schema is shared, set directly
DTD=org.gnome.shell.extensions.dash-to-dock
gsettings set $DTD dock-position 'BOTTOM'
gsettings set $DTD extend-height false
gsettings set $DTD dock-fixed true
gsettings set $DTD intellihide false
gsettings set $DTD autohide false
gsettings set $DTD transparency-mode 'FIXED'
gsettings set $DTD custom-background-color true
gsettings set $DTD background-color '#1c1c1e'
gsettings set $DTD background-opacity 0.72
gsettings set $DTD custom-theme-shrink false
gsettings set $DTD running-indicator-style 'DOTS'
gsettings set $DTD dash-max-icon-size 48
gsettings set $DTD show-apps-at-top false
gsettings set $DTD show-mounts false
gsettings set $DTD show-trash true
gsettings set $DTD click-action 'minimize-or-overview'
gsettings set $DTD force-straight-corner false

# wallpaper (desktop + lock screen)
gsettings set org.gnome.desktop.background picture-uri      "file://$WALL/Ventura-light.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALL/Ventura-dark.jpg"
gsettings set org.gnome.desktop.background picture-options  'zoom'
gsettings set org.gnome.desktop.screensaver picture-uri     "file://$WALL/Ventura-dark.jpg"

# enable our extensions, drop Ubuntu Dock
gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || true
gsettings set org.gnome.shell enabled-extensions \
  "['ding@rastersoft.com', 'tiling-assistant@ubuntu.com', 'GPaste@gnome-shell-extensions.gnome.org', 'dash-to-dock@micxgx.gmail.com', 'no-overview@fthx', 'Move_Clock@rmy.pobox.com', 'user-theme@gnome-shell-extensions.gcampax.github.com']"

#------------------------------------------------------------------ 8. done
echo ">>> [8/8] Done."
echo
echo "============================================================"
echo "  macOS look installed.  LOG OUT and back in to load it."
echo "  (Optional) login-screen background:  bash set-gdm-background.sh ~/Pictures/Wallpapers/Ventura-dark.jpg"
echo "============================================================"
