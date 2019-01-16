#!/bin/bash

# this sets the dock to a fixed width instead of autohiding.
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true

# this disables the power settings so the screen doesn't auto lock
gsettings set org.gnome.desktop.session idle-delay 0
