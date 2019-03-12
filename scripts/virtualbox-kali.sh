#!/usr/bin/env bash

logz='packer-upgrade.log'

DEBIAN_FRONTEND=noninteractive apt-get install virtualbox-guest-x11 --allow -o Dpkg::Options::='--force-confnew'| tee -a $log
echo 'packer' | sudo -S /sbin/reboot -p
