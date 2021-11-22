# -*- mode: ruby -*-
# vi: set ft=ruby :

$CIRCLECI=<<SCRIPT
tee "/etc/profile.d/circleci.sh">"/dev/null"<<EOF
# Terraform Cloud info
export TF_VAR_tc_auth_token="#{ENV['TF_VAR_tc_auth_token']}"

# packet info
export TF_VAR_packet_auth_token="#{ENV['TF_VAR_packet_auth_token']}"
export TF_VAR_packet_project_id="#{ENV['TF_VAR_packet_project_id']}"
export PACKET_API_TOKEN="#{ENV['TF_VAR_packet_auth_token']}"

# aws info
export TF_VAR_aws_access_key="#{ENV['TF_VAR_aws_access_key']}"
export TF_VAR_aws_secret_key="#{ENV['TF_VAR_aws_secret_key']}"
export TF_VAR_aws_region="#{ENV['TF_VAR_aws_region']}"

# vagrant cloud info
export VAGRANT_CLOUD_USER="#{ENV['vagrant_cloud_user']}" 
export VAGRANT_CLOUD_TOKEN="#{ENV['vagrant_cloud_token']}" 

# versioning for vagrant cloud
export MAJOR_RELEASE_VERSION="#{ENV['MAJOR_RELEASE_VERSION']}" 
export MINOR_RELEASE_VERSION="#{ENV['MINOR_RELEASE_VERSION']}" 

# text info
export PERSONAL_NUM="#{ENV['PERSONAL_NUM']}"
export TEXTBELT_KEY="#{ENV['TEXTBELT_KEY']}"

# hypervisors
export VMWARE_LICENSE="#{ENV['VMWARE_LICENSE']}"
EOF
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-20.04"

  config.vm.define "main", primary: true do |main|

    main.vm.provider :libvirt do |lv, override|
      override.vm.allowed_synced_folder_types = [:libvirt, :nfs]
      override.vm.box = "generic/ubuntu2004"
      override.vm.synced_folder ".", "/vagrant", nfs_version: 4, nfs_udp: false
      override.vm.synced_folder ".", "/home/vagrant/project", nfs_version: 4, nfs_udp: false
      override.vm.provision 'fix-dns', type: "shell", run: 'never' do |script|
        script.inline = <<-SHELL
          sudo sed -i -e '/nameservers:/d' -e '/addresses:/d' /etc/netplan/01-netcfg.yaml
          sudo netplan generate && sudo netplan apply
          sudo sed -i 's/^[[:alpha:]]/#&/' /etc/systemd/resolved.conf
          sudo systemctl restart systemd-resolved.service
        SHELL
      end
    end

    main.vm.provider "hyperv" do |h, override|
      override.vm.box = "generic/ubuntu2004"
      override.vm.provision 'fix-dns', type: "shell", run: 'never' do |script|
        script.inline = <<-SHELL
          set -x
          sudo sed -i -e '/nameservers:/d' -e '/addresses:/d' /etc/netplan/01-netcfg.yaml
          sudo netplan generate || exit 1
          sudo sed -i 's/^[[:alpha:]]/#&/' /etc/systemd/resolved.conf
          sudo systemctl restart systemd-resolved.service
          sudo netplan apply &
          exit 0
        SHELL
      end
    end

    main.vm.provider "virtualbox" do |vb, override|
      override.vm.network "private_network", ip: "192.168.34.22", virtualbox__intnet: "building_network"
    end

    main.vm.synced_folder ".", "/home/vagrant/project"
    main.vm.synced_folder ".", "/vagrant"
    # main.vm.synced_folder "~/src/mine/ansible_virtualization", "/roles"
    # https://askubuntu.com/questions/638387/logout-current-user-from-script#answer-638447
    main.vm.provision "shell", inline: "echo 'exec /vagrant/prov_vagrant/prov.sh' >> ~vagrant/.bashrc"
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
    remote.vm.provider "virtualbox" do |vb, override|
      override.vm.network "private_network", ip: "192.168.34.23", nfs_version: 4, virtualbox__intnet: "building_network"
    end
    remote.vm.provider :libvirt do |lv, override|
      override.vm.box = "generic/ubuntu2004"
      override.vm.synced_folder ".", "/vagrant", nfs_udp: false
      override.vm.allowed_synced_folder_types = [:libvirt, :nfs]
    end
    remote.vm.provision 'remote-setup', type: 'ansible' do |ansible|
      ansible.playbook = 'prov_vagrant/base.yml'
      ansible.version = 'latest'
    end
  end
end
