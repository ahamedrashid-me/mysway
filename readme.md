What's included
- Sway: backs up your existing configuration and configures startup entries.
- Waybar: CPU, memory, intel_backlight brightness, audio volume, battery, clock, workspace icons, system settings, and session/power menus.
- No duplicate bars on reload: adds a launcher that stops the old Waybar process before starting a new one.
- Network and Bluetooth: starts NetworkManager and Blueman tray applets.
- Power profiles: Power Saver, Balanced, and Performance menu.
- Foot: terminal font size 22.
- Appearance: Waybar font size 16.
- Safety: backs up configuration files before changing them.
How to use it
If you downloaded it to ~/Downloads, open Foot and run:
cd ~/Downloads
chmod +x setup-sway-waybar-foot.sh
./setup-sway-waybar-foot.sh


The script will request your password when it needs administrator privileges. Do not run the script with sudo; run it as your normal user.

Important: this is a full setup script, so it replaces your Waybar configuration with the layout included in the script. Your previous configuration is backed up, but review it before running if you've made additional custom changes.

After it finishes, test reloading Sway with Super + Shift + R. You should have one Waybar rather than a stack of bars.

One thing remains separate: your Surface's special keyboard shortcuts. This script doesn't yet add or verify all brightness and volume key bindings.
