# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
cat /vagrant/prov_vagrant/circleci.sh | tee "/etc/profile.d/circleci.sh">"/dev/null"
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "bento/debian-9"

  config.vm.provision "shell", inline: "echo '/vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
  config.vm.provision "shell", inline: $CIRCLECI # , run:"always"
end
