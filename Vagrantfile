# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
tee "/etc/profile.d/circleci.sh">"/dev/null"<<EOF
# packet info
export PACKET_API_KEY="#{ENV['TF_VAR_auth_token']}"
export PACKET_PROJECT_UUID="#{ENV['TF_VAR_project_id']}"
export TF_VAR_auth_token="#{ENV['TF_VAR_auth_token']}"
export TF_VAR_project_id="#{ENV['TF_VAR_project_id']}"

# aws info
export TF_VAR_aws_access_key="#{ENV['TF_VAR_aws_access_key']}"
export TF_VAR_aws_secret_key="#{ENV['TF_VAR_aws_secret_key']}"
export TF_VAR_aws_region="#{ENV['TF_VAR_aws_region']}"

# vagrant cloud info
export VAGRANT_CLOUD_USER="#{ENV['VAGRANT_CLOUD_USER']}" 
export VAGRANT_CLOUD_TOKEN="#{ENV['VAGRANT_CLOUD_TOKEN']}" 

# versioning for vagrant cloud
export MAJOR_RELEASE_VERSION=0
export MINOR_RELEASE_VERSION=0

# text info
export PERSONAL_NUM="#{ENV['PERSONAL_NUM']}"
export TEXTBELT_KEY="#{ENV['TEXTBELT_KEY']}"
EOF
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-20.04"

  config.vm.provision "shell", inline: "echo '/vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
  config.vm.provision "shell", inline: $CIRCLECI # , run:"always"
end
