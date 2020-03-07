#!/bin/bash

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

# adding user to docker group
usermod -aG docker vagrant
