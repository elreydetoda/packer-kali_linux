#!/bin/sh -eux

# thanks to bento project for this script
# set a default HOME_DIR environment variable if not set
echo 'packer' | sudo -S /sbin/reboot -p
DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-x11 --allow -o Dpkg::Options::='--force-confnew'| tee -a $log
# echo 'packer' | sudo -S /sbin/reboot -p
