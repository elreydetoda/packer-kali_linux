#!/bin/sh -eux


logz='packer-upgrade.log'
DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-x11 -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
echo 'packer' | sudo -S /sbin/reboot -p
