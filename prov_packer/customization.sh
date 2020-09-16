#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

function main(){
# this sets the dock to a fixed width instead of autohiding.
# no longer needed since 2019.4
#dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true

# this disables the power settings so the screen doesn't auto lock
# no longer needed since 2019.4
#gsettings set org.gnome.desktop.session idle-delay 0

# disable sleeping
# on battery
# gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
# plugged in
# no longer needed since 2019.4
#gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing

## installing http-screenshot.nse
# raw_github_url='https://raw.githubusercontent.com/SpiderLabs/Nmap-Tools/master/NSE/http-screenshot.nse'
# nse_location='/usr/share/nmap/scripts'
# apt install -y wkhtmltopdf
# curl -sSL ${nse_location}/http-screenshot.nse ${raw_github_url}
# nmap --script-updatedb
  :
}
# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
