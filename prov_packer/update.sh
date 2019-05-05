#!/bin/bash

# establishing a log file variable for the upgrade
logz='packer-upgrade.log'

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

## updating
# fix for old problem of not having the right repos
# echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free' > /etc/apt/sources.list
# echo 'deb-src http://http.kali.org/kali kali-rolling main contrib non-free' >> /etc/apt/sources.list
apt-get update --fix-missing | tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
