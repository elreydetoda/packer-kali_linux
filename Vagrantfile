# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
tee "/etc/profile.d/circleci.sh">"/dev/null"<<EOF

export VAGRANT_CLOUD_USER="elrey741"
export VAGRANT_CLOUD_TOKEN="#{ENV['VAGRANT_CLOUD_TOKEN']}" 
EOF
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "bento/debian-9"

  config.vm.provision "shell", inline: "echo '/vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
  config.vm.provision "shell", inline: $CIRCLECI, run:"always"
end
