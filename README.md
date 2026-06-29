# macOS look for Ubuntu 24.04 / GNOME 46

One-shot setup to make a fresh Ubuntu install look like macOS.

## Install
```bash
cd ~/macos-setup
bash install-macos-look.sh
```
Then **log out and back in** (GNOME extensions only load on a fresh session).

## What it sets up
- **WhiteSur** GTK theme + shell theme (dark/blue), icons, and macOS cursor
- **Inter** font (San Francisco-like)
- **Dash-to-Dock** — bottom, always-on, rounded, **dark translucent** (`#1c1c1e` @ 72%)
- **macOS Launchpad** icon on the show-apps button
- **Traffic-light** window buttons on the left
- **Clock top-right** (Move Clock), **no Activities overview at login** (no-overview)
- Dark translucent **top bar**
- **Ventura** wallpaper on desktop + lock screen

## Optional: login screen (GDM) background
```bash
sudo bash set-gdm-background.sh ~/Pictures/Wallpapers/Ventura-dark.jpg
sudo systemctl restart gdm3          # logs you out
# undo:
sudo bash set-gdm-background.sh --restore
```

## Notes / gotchas
- **No glass-blur** on the dock/top bar on purpose — Blur my Shell was unreliable on this
  AMD laptop (white bar at login, square corners). The dark-translucent dock is the stable
  look. Don't re-add dock blur unless you enjoy debugging it.
- Wallpapers land in `~/Pictures/Wallpapers/` (Big Sur, Monterey, Ventura, Sonoma — light+dark).
  Change desktop/lock/login to any of them.
- Tested on Ubuntu 24.04 / GNOME 46 / Wayland. Extension URLs auto-target your shell version.
