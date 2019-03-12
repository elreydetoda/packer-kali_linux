#!/bin/sh -eux


# set a default HOME_DIR environment variable if not set
logz='packer-upgrade.log'
DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-x11 -y -o Dpkg::Options::='--force-confnew'| tee -a $logz
echo 'packer' | sudo -S /sbin/reboot -p
