#!/usr/bin/env bash
# Sway + Waybar + Foot setup for Linux Mint / Ubuntu / Debian.
# Backs up existing user config files before changing them.
set -Eeuo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo "Run this script as your normal user, not with sudo."
  exit 1
fi
command -v apt-get >/dev/null || { echo "This script requires apt (Linux Mint/Ubuntu/Debian)."; exit 1; }

HOME_DIR="$HOME"
WAYBAR_DIR="$HOME_DIR/.config/waybar"
SCRIPTS_DIR="$WAYBAR_DIR/scripts"
SWAY_CONFIG="$HOME_DIR/.config/sway/config"
SWAY_SCRIPTS_DIR="$HOME_DIR/.config/sway/scripts"
FOOT_CONFIG="$HOME_DIR/.config/foot/foot.ini"
STAMP="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  if [[ -f "$1" ]]; then
    cp -a "$1" "$1.backup-$STAMP"
    echo "Backup: $1.backup-$STAMP"
  fi
}

echo '== Install required packages =='
sudo apt-get update
sudo apt-get install -y foot waybar wofi power-profiles-daemon cinnamon-control-center \
  network-manager-gnome blueman bluez pavucontrol brightnessctl

mkdir -p "$WAYBAR_DIR" "$SCRIPTS_DIR" "$HOME_DIR/.config/sway" "$SWAY_SCRIPTS_DIR" "$HOME_DIR/.config/foot"
backup_file "$WAYBAR_DIR/config"
backup_file "$WAYBAR_DIR/style.css"
backup_file "$SWAY_CONFIG"
backup_file "$FOOT_CONFIG"

echo '== Create power profile menu =='
cat > "$SCRIPTS_DIR/power-menu" <<'POWER_MENU'
#!/usr/bin/env bash
set -u
command -v powerprofilesctl >/dev/null 2>&1 || exit 1
current="$(powerprofilesctl get 2>/dev/null || echo unknown)"
choice="$(printf '%s\n' '🌿 Power Saver' '⚖ Balanced' '⚡ Performance' | wofi --dmenu --hide-search --lines 3 --width 230 --height 120 --location top_right --yoffset 38 --sort-order default --prompt "Power mode ($current)")"
case "$choice" in
  '🌿 Power Saver') powerprofilesctl set power-saver ;;
  '⚖ Balanced') powerprofilesctl set balanced ;;
  '⚡ Performance') powerprofilesctl set performance ;;
  *) exit 0 ;;
esac
POWER_MENU
chmod +x "$SCRIPTS_DIR/power-menu"

 echo '== Create session menu =='
cat > "$SCRIPTS_DIR/session-menu" <<'SESSION_MENU'
#!/usr/bin/env bash
set -u
choice="$(printf '%s\n' 'Log out' 'Reboot' 'Power off' | wofi --dmenu --hide-search --lines 3 --width 190 --height 120 --location top_right --yoffset 38 --sort-order default --prompt 'Session')"
case "$choice" in
  'Log out') swaymsg exit ;;
  'Reboot') systemctl reboot ;;
  'Power off') systemctl poweroff ;;
  *) exit 0 ;;
esac
SESSION_MENU
chmod +x "$SCRIPTS_DIR/session-menu"

echo '== Configure Waybar =='
cat > "$WAYBAR_DIR/config" <<EOF
{
  "layer": "top",
  "position": "top",
  "height": 42,
  "modules-left": ["custom/settings", "sway/workspaces", "sway/mode"],
  "modules-center": ["sway/window"],
  "modules-right": ["cpu", "memory", "backlight", "pulseaudio", "battery", "clock", "tray", "custom/session-menu"],
  "sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{icon}",
    "format-icons": {
      "1": "󰆍", "2": "󰈹", "3": "󰖟", "4": "󰉋", "5": "󰓓",
      "urgent": "", "focused": "", "default": ""
    }
  },
  "sway/mode": {"format": " {mode} "},
  "cpu": {"interval": 5, "format": " {usage}%"},
  "memory": {"interval": 5, "format": " {}%"},
  "backlight": {
    "device": "intel_backlight",
    "format": "☀ {percent}%",
    "tooltip": true,
    "tooltip-format": "Brightness: {percent}%",
    "on-scroll-up": "brightnessctl -d intel_backlight set 5%+",
    "on-scroll-down": "brightnessctl -d intel_backlight set 5%-"
  },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟 muted",
    "format-icons": {"default": ["󰕿", "󰖀", "󰕾"]},
    "scroll-step": 5,
    "on-click": "pavucontrol",
    "tooltip": true,
    "tooltip-format": "Audio: {volume}%"
  },
  "battery": {
    "interval": 15,
    "format": "BAT {capacity}%",
    "format-charging": "CHG {capacity}%",
    "format-discharging": "BAT {capacity}%",
    "format-full": "FULL {capacity}%",
    "on-click": "$SCRIPTS_DIR/power-menu",
    "states": {"warning": 30, "critical": 15},
    "tooltip": true,
    "tooltip-format": "Battery: {capacity}%"
  },
  "clock": {"format": " {:%a %d %b  %H:%M}", "tooltip": true},
  "tray": {"spacing": 8},
  "custom/settings": {
    "format": "",
    "tooltip": true,
    "tooltip-format": "System Settings",
    "on-click": "cinnamon-settings"
  },
  "custom/session-menu": {
    "format": "",
    "tooltip": true,
    "tooltip-format": "Session and power menu",
    "on-click": "$SCRIPTS_DIR/session-menu"
  }
}
EOF
python3 -m json.tool "$WAYBAR_DIR/config" >/dev/null

echo '== Set Waybar font size to 16px =='
STYLE="$WAYBAR_DIR/style.css"
if [[ ! -f "$STYLE" ]]; then
  cat > "$STYLE" <<'CSS'
/* BEGIN sway-custom-font-size: change 16px to your preferred size */
* {
    font-family: "Noto Sans", sans-serif;
    font-size: 16px;
}
/* END sway-custom-font-size */
CSS
elif grep -q 'BEGIN sway-custom-font-size' "$STYLE"; then
  python3 - "$STYLE" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text()
s=re.sub(r'/\* BEGIN sway-custom-font-size.*?/\* END sway-custom-font-size \*/', '''/* BEGIN sway-custom-font-size: change 16px to your preferred size */
* {
    font-family: "Noto Sans", sans-serif;
    font-size: 16px;
}
/* END sway-custom-font-size */''', s, flags=re.S)
p.write_text(s)
PY
else
  cat >> "$STYLE" <<'CSS'

/* BEGIN sway-custom-font-size: change 16px to your preferred size */
* {
    font-family: "Noto Sans", sans-serif;
    font-size: 16px;
}
/* END sway-custom-font-size */
CSS
fi

echo '== Set Foot terminal font size to 22 =='
if [[ ! -f "$FOOT_CONFIG" ]]; then
  printf '[main]\nfont=monospace:size=22\n' > "$FOOT_CONFIG"
else
  python3 - "$FOOT_CONFIG" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines(); out=[]
in_main=False; main_found=False; font_written=False
for line in lines:
    t=line.strip()
    if t.startswith('[') and t.endswith(']'):
        if in_main and not font_written:
            out.append('font=monospace:size=22'); font_written=True
        in_main=(t.lower()=='[main]'); main_found |= in_main; out.append(line); continue
    if in_main and t.startswith('font='):
        if not font_written: out.append('font=monospace:size=22'); font_written=True
        continue
    out.append(line)
if in_main and not font_written: out.append('font=monospace:size=22')
elif not main_found:
    if out and out[-1] != '': out.append('')
    out += ['[main]', 'font=monospace:size=22']
p.write_text('\n'.join(out)+'\n')
PY
fi

echo '== Create reload-safe Waybar launcher =='
cat > "$SWAY_SCRIPTS_DIR/restart-waybar.sh" <<'WAYBAR_LAUNCHER'
#!/usr/bin/env bash
# Keep exactly one Waybar process when Sway starts or reloads.
pkill -x waybar 2>/dev/null || true
sleep 0.5
exec waybar
WAYBAR_LAUNCHER
chmod +x "$SWAY_SCRIPTS_DIR/restart-waybar.sh"

echo '== Ensure Waybar and network/Bluetooth tray applets start with Sway =='
if [[ -f "$SWAY_CONFIG" ]]; then
  python3 - "$SWAY_CONFIG" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
# Remove existing simple startup lines for these commands to avoid duplicates.
for command in ("waybar", "~/.config/sway/scripts/restart-waybar.sh", "nm-applet", "blueman-applet"):
    s = re.sub(r'(?m)^[ \t]*exec(?:_always)?(?:[ \t]+--no-startup-id)?[ \t]+' + re.escape(command) + r'(?:[ \t].*)?[ \t]*\n?', '', s)
managed = "# Start Waybar and network/Bluetooth tray icons\nexec_always ~/.config/sway/scripts/restart-waybar.sh\nexec_always --no-startup-id nm-applet\nexec_always --no-startup-id blueman-applet\n"
marker = "# Startup applications"
if marker in s:
    pos = s.find(marker)
    line_end = s.find("\n", pos)
    if line_end < 0:
        s += "\n" + managed
    else:
        s = s[:line_end + 1] + managed + s[line_end + 1:]
else:
    s = s.rstrip() + "\n\n" + managed
p.write_text(s)
PY
else
  echo "No Sway config found at $SWAY_CONFIG; skipped Sway startup configuration."
fi
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl enable --now power-profiles-daemon.service || echo 'Warning: could not enable power-profiles-daemon.'
fi

python3 -m json.tool "$WAYBAR_DIR/config" >/dev/null
echo
echo 'Setup complete. Backups were created with suffix .backup-'"$STAMP"'.'
echo "Waybar font size: 16px in $WAYBAR_DIR/style.css"
echo "Foot font size: 22 in $FOOT_CONFIG"
echo 'Waybar startup is reload-safe: the launcher stops any old Waybar before starting one.'
echo 'Reload Sway with Super+Shift+R or run: swaymsg reload'
echo 'Wi-Fi/network settings: click the NetworkManager tray icon in Waybar.'
echo 'Bluetooth controls: click the Blueman tray icon in Waybar.'
echo 'Audio: scroll on the volume module to change volume; click it for Sound settings.'
echo 'Brightness: scroll on the brightness module to change brightness.'
echo 'This setup replaces the Waybar config with the customized layout shown in this script.'
