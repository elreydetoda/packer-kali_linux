#!/bin/bash

# updateing
logz='packer-upgrade.log'
echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free' > /etc/apt/sources.list
echo 'deb-src http://http.kali.org/kali kali-rolling main contrib non-free' >> /etc/apt/sources.list
apt-get update | tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get install virtualbox-guest-x11 --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $log
