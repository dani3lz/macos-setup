#!/usr/bin/env bash
###############################################################################
#  Firefox (snap) macOS-look + declutter
#  - WhiteSur Firefox theme (rounded macOS tabs/toolbar)
#  - built-in Dark theme (no purple/Alpenglow)
#  - declutter: no Pocket, no Firefox View, bookmarks bar on new-tab only,
#    clean new-tab page
#
#  IMPORTANT: run Firefox once (to create the profile) then CLOSE it, then run:
#      bash setup-firefox.sh
###############################################################################
set -uo pipefail
note(){ echo ">>> $*"; }
warn(){ echo "  ⚠ $*"; }

FFDIR="$HOME/snap/firefox/common/.mozilla/firefox"
[ -d "$FFDIR" ] || { echo "Snap Firefox profile dir not found ($FFDIR). Launch Firefox once, close it, then re-run."; exit 1; }

# must be closed (we edit the profile)
if pgrep -x firefox >/dev/null; then echo "Firefox is running — close it completely, then re-run."; exit 1; fi

# detect the default profile dir dynamically (name is random per install)
PROF="$(awk -F= '/^\[Profile/{p=""} /^Path=/{p=$2} /^Default=1/{print p}' "$FFDIR/profiles.ini" 2>/dev/null | head -1)"
[ -n "${PROF:-}" ] && PROF="$FFDIR/$PROF"
[ -d "${PROF:-}" ] || PROF="$(find "$FFDIR" -maxdepth 1 -name '*.default*' -type d | head -1)"
[ -d "${PROF:-}" ] || { echo "No Firefox profile found. Launch Firefox once, close it, then re-run."; exit 1; }
note "Using profile: $PROF"

#------------------------------------------------------------------ 1. WhiteSur Firefox theme
note "[1/3] Installing WhiteSur Firefox theme…"
cd /tmp && rm -rf WhiteSur-firefox-theme
if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-firefox-theme.git >/dev/null 2>&1; then
  ( cd WhiteSur-firefox-theme && ./install.sh ) >/dev/null 2>&1 \
    && echo "    ✓ theme installed" || warn "theme install reported an issue"
  rm -rf /tmp/WhiteSur-firefox-theme
else warn "could not clone WhiteSur-firefox-theme (skipped)"; fi

#------------------------------------------------------------------ 2. built-in Dark theme
note "[2/3] Switching to built-in Dark theme…"
DARK="firefox-compact-dark@mozilla.org"
cp "$PROF/prefs.js" "$PROF/prefs.js.bak" 2>/dev/null || true
if [ -f "$PROF/prefs.js" ] && grep -q "extensions.activeThemeID" "$PROF/prefs.js"; then
  sed -i "s|\"extensions.activeThemeID\", \"[^\"]*\"|\"extensions.activeThemeID\", \"$DARK\"|" "$PROF/prefs.js"
else
  echo "user_pref(\"extensions.activeThemeID\", \"$DARK\");" >> "$PROF/prefs.js"
fi
if [ -f "$PROF/extensions.json" ]; then
  cp "$PROF/extensions.json" "$PROF/extensions.json.bak"
  python3 - "$PROF/extensions.json" "$DARK" <<'PY' 2>/dev/null || true
import json,sys
p,dark=sys.argv[1],sys.argv[2]
d=json.load(open(p))
for a in d.get('addons',[]):
    if a.get('type')=='theme':
        on=(a.get('id')==dark); a['active']=on; a['userDisabled']=not on
json.dump(d,open(p,'w'))
PY
fi
rm -f "$PROF/addonStartup.json.lz4"   # rebuilt on launch with the new theme
echo "    ✓ dark theme set"

#------------------------------------------------------------------ 3. declutter (user.js)
note "[3/3] Decluttering UI…"
touch "$PROF/user.js"; cp "$PROF/user.js" "$PROF/user.js.bak" 2>/dev/null || true
# theme install needs this; keep it if already there, else add
grep -q "legacyUserProfileCustomizations" "$PROF/user.js" 2>/dev/null \
  || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$PROF/user.js"
# add declutter block once
if ! grep -q "declutter (macOS-clean)" "$PROF/user.js"; then
cat >> "$PROF/user.js" <<'EOF'

// --- declutter (macOS-clean) ---
user_pref("extensions.pocket.enabled", false);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.toolbars.bookmarks.visibility", "newtab");
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
EOF
fi
echo "    ✓ declutter applied"
# NOTE: density left at the WhiteSur theme's default — forcing compact misaligns the theme.

echo
echo "============================================================"
echo "  Firefox set up. Launch it — dark WhiteSur theme + decluttered."
echo "  Optional full-macOS touch: Customize Toolbar → drag the '+' (New Tab)"
echo "  button up into the title-bar area."
echo "============================================================"
