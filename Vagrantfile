# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
tee "/etc/profile.d/circleci.sh">"/dev/null"<<EOF
# packet info
export TF_VAR_auth_token="#{ENV['TF_VAR_packet_auth_token']}"
export TF_VAR_project_id="#{ENV['TF_VAR_packet_project_id']}"

# aws info
export TF_VAR_aws_access_key="#{ENV['TF_VAR_aws_access_key']}"
export TF_VAR_aws_secret_key="#{ENV['TF_VAR_aws_secret_key']}"
export TF_VAR_aws_region="#{ENV['TF_VAR_aws_region']}"

# vagrant cloud info
export VAGRANT_CLOUD_USER="#{ENV['vagrant_cloud_user']}" 
export VAGRANT_CLOUD_TOKEN="#{ENV['vagrant_cloud_token']}" 

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

  config.vm.define "main", primary: true do |main|
    main.vm.network "private_network", ip: "192.168.34.22", virtualbox__intnet: "building_network"
    main.vm.synced_folder ".", "/home/vagrant/project_folder"
    main.vm.synced_folder ".", "/vagrant"
    # main.vm.synced_folder "~/src/mine/ansible_virtualization", "/roles"
    main.vm.provision "shell", inline: "echo '/vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
    main.vm.provision 'key-setup', type: "shell", inline: <<-SHELL
      # https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingmodifiedscripthardening
      set -${-//[sc]/}eu${DEBUG+xv}o pipefail
      vagrant_priv_key='/vagrant/.vagrant/machines/builder/virtualbox/private_key'
      ssh_home='/home/vagrant/.ssh'
      mkdir -p "${ssh_home}"

      if [[ -r "${vagrant_priv_key}" ]] ; then
        cat "${vagrant_priv_key}" > "${ssh_home}/id_rsa"
        chmod 600 "${ssh_home}/id_rsa"
        chown vagrant:vagrant "${ssh_home}/id_rsa"
      fi
    SHELL

    main.vm.provision "shell", inline: $CIRCLECI # , run:"always"
    main.vm.provision "shell", inline: <<-SHELL
      # https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingmodifiedscripthardening
      set -${-//[sc]/}eu${DEBUG+xv}o pipefail

      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y git tmux screen
    SHELL
  end
  config.vm.define "builder", autostart: false do |remote|
    remote.vm.network "private_network", ip: "192.168.34.23", virtualbox__intnet: "building_network"
    remote.vm.provision 'remote-setup', type: 'ansible' do |ansible|
      ansible.playbook = 'prov_vagrant/base.yml'
      ansible.version = 'latest'
    end
  end
end
