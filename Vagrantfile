# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
tee "/etc/profile.d/circleci.sh">"/dev/null"<<EOF
# packet info
export PACKET_API_KEY="#{ENV['PACKET_API_KEY']}"
export PACKET_PROJECT_UUID="#{ENV['PACKET_PROJECT_UUID']}"

# vagrant cloud info
export VAGRANT_CLOUD_USER="elrey741"
export VAGRANT_CLOUD_TOKEN="#{ENV['VAGRANT_CLOUD_TOKEN']}" 

# versioning for vagrant cloud
export MAJOR_RELEASE_VERSION=0
export MINOR_RELEASE_VERSION=0
EOF
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "bento/debian-9"

  config.vm.provision "shell", inline: "echo '/vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
  config.vm.provision "shell", inline: $CIRCLECI # , run:"always"
end
