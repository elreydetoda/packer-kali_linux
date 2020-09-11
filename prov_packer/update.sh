#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail


function disable_system_misc(){

  # thanks to bento project
  ########################################
  # Disable systemd apt timers/services
  systemctl stop apt-daily.timer;
  systemctl stop apt-daily-upgrade.timer;
  systemctl disable apt-daily.timer;
  systemctl disable apt-daily-upgrade.timer;
  systemctl mask apt-daily.service;
  systemctl mask apt-daily-upgrade.service;
  systemctl daemon-reload;

# Disable periodic activities of apt
  cat <<EOF >/etc/apt/apt.conf.d/10periodic;
APT::Periodic::Enable "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
########################################
}

function update_os(){

  ## updating
  export DEBIAN_FRONTEND=noninteractive
  # fix for old problem of not having the right repos
  # echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free' > /etc/apt/sources.list
  # echo 'deb-src http://http.kali.org/kali kali-rolling main contrib non-free' >> /etc/apt/sources.list
  apt-get update --fix-missing | tee -a $logz
  apt-get upgrade -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
  apt-get dist-upgrade -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
  apt-get autoremove -y -o Dpkg::Options::='--force-confnew'| tee -a $logz

}

function main(){

  # establishing a log file variable for the upgrade
  logz='packer-upgrade.log'

}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
