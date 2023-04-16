#!/bin/sh -eux

case "$PACKER_BUILDER_TYPE" in
  virtualbox-iso | virtualbox-ovf)

    logz='packer-upgrade.log'
    DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-x11 -y -o Dpkg::Options::='--force-confnew' | tee -a $logz
    echo 'packer' | sudo -S /sbin/reboot -p
    ;;

esac
