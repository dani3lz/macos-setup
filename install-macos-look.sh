#!/usr/bin/env bash
###############################################################################
#  macOS look for Ubuntu / GNOME (Wayland)
#  Tested on Ubuntu 24.04 / GNOME 46. Written to adapt to newer GNOME too:
#  - extension downloads auto-target your shell version
#  - settings are applied tolerantly (a renamed/missing key warns, doesn't crash)
#  - the dock patch is verified, and unavailable extensions are reported
#
#  Run on a fresh install:   bash install-macos-look.sh
#  Then LOG OUT and back in (extensions load on a fresh session).
#
#  NOTE: dock/panel glass-blur (Blur my Shell) is intentionally NOT used — it was
#  unreliable. The dock uses a hard-coded dark translucent color, which is stable.
###############################################################################
set -uo pipefail   # NOT -e: we want to continue past individual non-fatal steps

# ---- fatal helper for the few steps that must succeed ----
die() { echo "!! FATAL: $*" >&2; exit 1; }
note() { echo ">>> $*"; }
WARN=0; warn() { echo "  ⚠ $*"; WARN=$((WARN+1)); }

SHELL_VER="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
[ -n "$SHELL_VER" ] || die "GNOME Shell not found — is this a GNOME session?"
OS_VER="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
note "Target: $OS_VER  |  GNOME Shell $SHELL_VER"
[ "$SHELL_VER" -ge 46 ] 2>/dev/null || warn "Script tuned for GNOME 46+; older may need tweaks."

USER_ICONS="$HOME/.local/share/icons"
USER_EXT="$HOME/.local/share/gnome-shell/extensions"
SRC="$HOME/.local/src"
WALL="$HOME/Pictures/Wallpapers"
mkdir -p "$SRC" "$WALL" "$HOME/.local/share/fonts/Inter"

# tolerant gsettings: warn (don't crash) if a key was renamed/removed on a newer GNOME
gset() {
  local schema="$1" key="$2"; shift 2
  if gsettings writable "$schema" "$key" >/dev/null 2>&1; then
    gsettings set "$schema" "$key" "$@" 2>/dev/null || warn "could not set $schema $key"
  else
    warn "key not present on this GNOME: $schema $key (skipped)"
  fi
}

#------------------------------------------------------------------ 1. deps
note "[1/8] apt dependencies (needs sudo)…"
sudo apt-get update -y || die "apt update failed"
sudo apt-get install -y git curl unzip sassc libxml2-utils libglib2.0-dev-bin \
    gnome-tweaks gnome-shell-extension-manager gnome-screenshot fontconfig \
    || die "apt install failed"

#------------------------------------------------------------------ 2. WhiteSur theme/icons/cursor/wallpapers
note "[2/8] WhiteSur theme, icons, cursor, wallpapers…"
cd "$SRC"
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2" || warn "clone failed: $1"; }
clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git   WhiteSur-gtk-theme
clone https://github.com/vinceliuice/WhiteSur-icon-theme.git  WhiteSur-icon-theme
clone https://github.com/vinceliuice/WhiteSur-cursors.git     WhiteSur-cursors
clone https://github.com/vinceliuice/WhiteSur-wallpapers.git  WhiteSur-wallpapers
[ -d WhiteSur-gtk-theme  ] && ( cd WhiteSur-gtk-theme  && ./install.sh -c Dark -t blue ) || warn "gtk theme install issue"
[ -d WhiteSur-icon-theme ] && ( cd WhiteSur-icon-theme && ./install.sh -t default )     || warn "icon theme install issue"
[ -d WhiteSur-cursors    ] && ( cd WhiteSur-cursors    && ./install.sh )                || warn "cursor install issue"
cp WhiteSur-wallpapers/4k/*.jpg "$WALL/" 2>/dev/null || warn "no wallpapers copied"

#------------------------------------------------------------------ 3. Inter font
note "[3/8] Inter font…"
if curl -fsSL -o /tmp/inter.zip https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip; then
  rm -rf /tmp/inter_x && unzip -o -q /tmp/inter.zip -d /tmp/inter_x
  find /tmp/inter_x -iname "Inter*.ttf" -exec cp {} "$HOME/.local/share/fonts/Inter/" \; 2>/dev/null
  fc-cache -f >/dev/null 2>&1
else warn "Inter download failed (font step skipped)"; fi

#------------------------------------------------------------------ 4. GNOME extensions (auto-target shell version)
note "[4/8] GNOME extensions for shell $SHELL_VER…"
install_ext() {
  local uuid="$1" url
  url="https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${SHELL_VER}"
  if curl -fsSL -o "/tmp/$uuid.zip" "$url" && gnome-extensions install --force "/tmp/$uuid.zip" 2>/dev/null; then
    echo "    ✓ $uuid"
  else
    warn "extension '$uuid' has no build for GNOME $SHELL_VER yet (or download failed) — install later from extensions.gnome.org"
  fi
}
install_ext "dash-to-dock@micxgx.gmail.com"
install_ext "no-overview@fthx"
install_ext "Move_Clock@rmy.pobox.com"
install_ext "user-theme@gnome-shell-extensions.gcampax.github.com"
extset() { local uuid="$1"; shift; GSETTINGS_SCHEMA_DIR="$USER_EXT/$uuid/schemas" gsettings set "$@" 2>/dev/null || true; }
glib-compile-schemas "$USER_EXT/user-theme@gnome-shell-extensions.gcampax.github.com/schemas" 2>/dev/null || true

#------------------------------------------------------------------ 5. Launchpad icon + dash-to-dock patch
note "[5/8] Launchpad icon + Dash-to-Dock patch…"
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
D2D="$USER_EXT/dash-to-dock@micxgx.gmail.com/appIcons.js"
if [ -f "$D2D" ]; then
  if ! grep -q "launchpad-macos.svg" "$D2D"; then
    # match dash-to-dock's show-apps iconName line in any future-ish whitespace form
    sed -i "s|^\([[:space:]]*\)this\._iconActor\.iconName *= *.view-app-grid.*|\1this._iconActor.gicon = Gio.icon_new_for_string('$LP');|" "$D2D"
  fi
  grep -q "launchpad-macos.svg" "$D2D" \
    && echo "    ✓ dock show-apps icon patched" \
    || warn "couldn't patch Dash-to-Dock show-apps icon (its code may have changed) — Launchpad icon may fall back to default"
else
  warn "Dash-to-Dock not installed — skipped icon patch"
fi

#------------------------------------------------------------------ 6. dark translucent top bar
note "[6/8] Dark translucent top bar (theme CSS)…"
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
  echo "    ✓ panel CSS added"
else
  [ -f "$CSS" ] || warn "WhiteSur shell CSS not found — top bar will use theme default"
fi

#------------------------------------------------------------------ 7. settings (tolerant)
note "[7/8] Applying settings…"
IFACE=org.gnome.desktop.interface
gset $IFACE color-scheme 'prefer-dark'
gset $IFACE gtk-theme 'WhiteSur-Dark-blue'
gset $IFACE icon-theme 'WhiteSur'
gset $IFACE cursor-theme 'WhiteSur-cursors'
gset $IFACE font-name 'Inter 11'
gset $IFACE document-font-name 'Inter 11'
gset $IFACE enable-hot-corners false
gset $IFACE accent-color 'blue'      # GNOME 47+ only; harmlessly skipped on 46
gset org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gset org.gnome.desktop.wm.preferences titlebar-font 'Inter Semi-Bold 11'

extset "user-theme@gnome-shell-extensions.gcampax.github.com" org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark-blue'
dconf write /org/gnome/shell/extensions/user-theme/name "'WhiteSur-Dark-blue'" 2>/dev/null || true

DTD=org.gnome.shell.extensions.dash-to-dock
if gsettings list-schemas 2>/dev/null | grep -q "$DTD"; then
  gset $DTD dock-position 'BOTTOM'
  gset $DTD extend-height false
  gset $DTD dock-fixed true
  gset $DTD intellihide false
  gset $DTD autohide false
  gset $DTD transparency-mode 'FIXED'
  gset $DTD custom-background-color true
  gset $DTD background-color '#1c1c1e'
  gset $DTD background-opacity 0.72
  gset $DTD custom-theme-shrink false
  gset $DTD running-indicator-style 'DOTS'
  gset $DTD dash-max-icon-size 48
  gset $DTD show-apps-at-top false
  gset $DTD show-mounts false
  gset $DTD show-trash true
  gset $DTD click-action 'minimize-or-overview'
  gset $DTD force-straight-corner false
else
  warn "Dash-to-Dock schema not loaded yet — re-run this block after first login if the dock looks default"
fi

# GNOME Terminal: subtle 5% transparency (default profile, detected dynamically)
TPID="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d \"'\")"
if [ -n "$TPID" ]; then
  TPROF="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TPID/"
  gsettings set "$TPROF" use-transparent-background true 2>/dev/null || warn "terminal transparency unsupported here"
  gsettings set "$TPROF" background-transparency-percent 5 2>/dev/null || true
fi

# wallpaper (desktop + lock)
[ -f "$WALL/Ventura-dark.jpg" ] && {
  gset org.gnome.desktop.background picture-uri      "file://$WALL/Ventura-light.jpg"
  gset org.gnome.desktop.background picture-uri-dark "file://$WALL/Ventura-dark.jpg"
  gset org.gnome.desktop.background picture-options  'zoom'
  gset org.gnome.desktop.screensaver picture-uri     "file://$WALL/Ventura-dark.jpg"
}

# enable our extensions, drop Ubuntu Dock
gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || true
gset org.gnome.shell enabled-extensions \
  "['ding@rastersoft.com', 'tiling-assistant@ubuntu.com', 'GPaste@gnome-shell-extensions.gnome.org', 'dash-to-dock@micxgx.gmail.com', 'no-overview@fthx', 'Move_Clock@rmy.pobox.com', 'user-theme@gnome-shell-extensions.gcampax.github.com']"

#------------------------------------------------------------------ 8. done
note "[8/8] Done."
echo
echo "============================================================"
if [ "$WARN" -eq 0 ]; then echo "  ✅ macOS look installed with no warnings."
else echo "  ⚠ Installed with $WARN warning(s) above — usually a newer GNOME"
     echo "     where an extension/key differs. The look still mostly applies;"
     echo "     check the warnings and install any missing extension manually."; fi
echo "  >>> LOG OUT and back in to load everything."
echo "  (Optional) login bg:  sudo bash set-gdm-background.sh ~/Pictures/Wallpapers/Ventura-dark.jpg"
echo "============================================================"
