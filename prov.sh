#!/bin/bash

# updateing
logz='packer-upgrade.log'
echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free' > /etc/apt/sources.list
echo 'deb-src http://http.kali.org/kali kali-rolling main contrib non-free' >> /etc/apt/sources.list
apt-get update | tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $logz
DEBIAN_FRONTEND=noninteractive apt-get install virtualbox-guest-x11 --force-yes -o Dpkg::Options::='--force-confnew'| tee -a $log



# getting docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo 'deb https://download.docker.com/linux/debian stretch stable' > /etc/apt/sources.list.d/docker.list
# for outdated kali's
# apt-get update
# apt-key adv --keyserver hkp://keys.gnupg.net --recv-keys 7D8D0BF6
apt-get update
# be careful this will remove your current docker
apt-get remove docker docker-engine docker.io -y
apt-get install docker-ce -y
