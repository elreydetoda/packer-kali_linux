#!/bin/bash

# this sets the dock to a fixed width instead of autohiding.
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true

# this disables the power settings so the screen doesn't auto lock
gsettings set org.gnome.desktop.session idle-delay 0

# disable sleeping
# on battery
# gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
# plugged in
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing

## installing http-screenshot.nse
# raw_github_url='https://raw.githubusercontent.com/SpiderLabs/Nmap-Tools/master/NSE/http-screenshot.nse'
# nse_location='/usr/share/nmap/scripts'
# apt install -y wkhtmltopdf
# curl -sSL ${nse_location}/http-screenshot.nse ${raw_github_url}
# nmap --script-updatedb
