packer {
  required_version = ">= 1.8.6"
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
    vagrant = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/vagrant"
    }
    virtualbox = {
      version = ">= 1.0.4"
      source  = "github.com/hashicorp/virtualbox"
    }
    vmware = {
      version = ">= 1.0.7"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

##################################################
# need input
variable "build_version" {
  type    = string
  default = "min"
}

variable "iso_checksum" {
  type = string
  default = "344a8c948af62f7a288e3dc658291ec3d3cfcdbe5ad1e2f45334740bd6ff481d"
}

variable "iso_url" {
  type = string
  default = "https://cdimage.kali.org/current/kali-linux-2023.1-installer-netinst-amd64.iso"
}

variable "headless" {
  type    = bool
  default = false
}

variable "vm_name" {
  type    = string
  default = "kali-linux_amd64"
}

# I don't need to change
variable "vm_box_provider" {
  type    = string
  default = "elrey741"
}

variable "vm_version" {
  type    = string
  default = "0.0.0"
}

##################################################

variable "box_basename" {
  type    = string
  default = "red-automated_kali"
}

variable "cpus" {
  type    = string
  default = "2"
}

variable "disk_size" {
  type    = string
  default = "65536"
}

variable "http_proxy" {
  type    = string
  default = "${env("http_proxy")}"
}

variable "https_proxy" {
  type    = string
  default = "${env("https_proxy")}"
}

variable "no_proxy" {
  type    = string
  default = "${env("no_proxy")}"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "template" {
  type    = string
  default = "packerAutoKali"
}

// variable "VAGRANT_CLOUD_TOKEN" {
//   type      = string
//   default   = ""
//   sensitive = true
// }

variable "vagrantfile" {
  type    = string
  default = "templates/vagrantfile-kali_linux.template"
}

locals {
  build_directory       = "${path.root}/builds"
  base_provisioning_dir = "${path.root}/provisioning"
  bento_debian_dir      = "${local.base_provisioning_dir}/bento/packer_templates/scripts/debian"
  http_directory        = "http"
  boot_command = [
    "<wait><esc>",
    "<wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kali-linux-rolling-${var.build_version}-preseed.cfg",
    // " debian-installer=en_US.UTF-8",
    " locale=en_US.UTF-8",
    " keyboard-configuration/xkb-keymap=us",
    // " console-setup/ask_detect=false",
    // " console-keymaps-at/keymap=us",
    " netcfg/get_hostname={{ .Name }}<enter>"
  ]
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "3h"
  ssh_port         = 22
  shutdown_command = "echo 'vagrant' | sudo -S /sbin/shutdown -hP now"
}

source "qemu" "vm" {
  boot_command       = local.boot_command
  boot_wait          = "10s"
  cpus               = var.cpus
  disk_cache         = "unsafe"
  disk_compression   = true
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_image         = false
  disk_interface     = "virtio-scsi"
  disk_size          = var.disk_size
  headless           = var.headless
  http_directory     = local.http_directory
  iso_checksum       = var.iso_checksum
  iso_url            = var.iso_url
  memory             = var.memory
  output_directory   = "${local.build_directory}/packer-${var.template}-qemu"
  shutdown_command   = local.shutdown_command
  ssh_password       = local.ssh_password
  ssh_port           = local.ssh_port
  ssh_timeout        = local.ssh_timeout
  ssh_username       = local.ssh_username
  vm_name            = "${var.template}-${var.build_version}"
}

source "virtualbox-iso" "vm" {
  boot_command            = local.boot_command
  boot_wait               = "10s"
  cpus                    = var.cpus
  disk_size               = var.disk_size
  gfx_controller          = "vmsvga"
  gfx_vram_size           = "48"
  guest_additions_path    = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type           = "Debian_64"
  hard_drive_interface    = "sata"
  headless                = var.headless
  http_directory          = local.http_directory
  iso_checksum            = var.iso_checksum
  iso_url                 = var.iso_url
  memory                  = var.memory
  output_directory        = "${local.build_directory}/packer-${var.template}-virtualbox"
  shutdown_command        = local.shutdown_command
  ssh_password            = local.ssh_password
  ssh_port                = local.ssh_port
  ssh_timeout             = local.ssh_timeout
  ssh_username            = local.ssh_username
  virtualbox_version_file = ".vbox_version"
  vm_name                 = "${var.template}-${var.build_version}"
}

source "vmware-iso" "vm" {
  boot_command        = local.boot_command
  boot_wait           = "10s"
  cpus                = var.cpus
  disk_size           = var.disk_size
  guest_os_type       = "debian8-64"
  headless            = var.headless
  http_directory      = local.http_directory
  iso_checksum        = var.iso_checksum
  iso_url             = var.iso_url
  memory              = var.memory
  output_directory    = "${local.build_directory}/packer-${var.template}-vmware"
  shutdown_command    = local.shutdown_command
  ssh_password        = local.ssh_password
  ssh_port            = local.ssh_port
  ssh_timeout         = local.ssh_timeout
  ssh_username        = local.ssh_username
  tools_upload_flavor = "linux"
  vm_name             = "${var.template}-${var.build_version}"
  vmx_data = {
    "cpuid.coresPerSocket"    = "1"
    "ethernet0.pciSlotNumber" = "32"
  }
  vmx_remove_ethernet_interfaces = true
}

build {
  sources = ["source.qemu.vm", "source.virtualbox-iso.vm", "source.vmware-iso.vm"]

  provisioner "shell" {
    environment_vars = [
      "HOME_DIR=/home/vagrant",
      "http_proxy=${var.http_proxy}",
      "https_proxy=${var.https_proxy}",
      "no_proxy=${var.no_proxy}"
    ]
    execute_command   = "echo 'vagrant' | {{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"
    expect_disconnect = "true"
    scripts = [
      "${local.base_provisioning_dir}/full-update.sh",
      "${local.base_provisioning_dir}/vagrant.sh",
      "${local.base_provisioning_dir}/customization.sh",
      "${local.base_provisioning_dir}/docker.sh",
      "${local.base_provisioning_dir}/networking.sh",
      "${local.base_provisioning_dir}/virtualbox.sh",
      "${local.bento_debian_dir}/update_debian.sh",
      "${local.bento_debian_dir}/../_common/motd.sh",
      "${local.bento_debian_dir}/../_common/sshd.sh",
      "${local.bento_debian_dir}/networking_debian.sh",
      "${local.bento_debian_dir}/sudoers_debian.sh",
      "${local.bento_debian_dir}/../_common/vagrant.sh",
      "${local.bento_debian_dir}/systemd_debian.sh",
      "${local.bento_debian_dir}/../_common/virtualbox.sh",
      "${local.bento_debian_dir}/../_common/vmware_debian_ubuntu.sh",
      "${local.bento_debian_dir}/../_common/parallels.sh",
      "${local.bento_debian_dir}/hyperv_debian.sh",
      "${local.base_provisioning_dir}/cleanup.sh",
      "${local.bento_debian_dir}/../_common/minimize.sh",
    ]
  }

  post-processors {
    // post-processor "artifice" {
    //   files = ["${var.build_directory}/${var.box_basename}.{{ .Provider }}.box"]
    // }
    post-processor "vagrant" {
      // keep_input_artifact  = true
      compression_level    = 9
      output               = "${local.build_directory}/${var.box_basename}.{{ .Provider }}-${var.build_version}.box"
      vagrantfile_template = "${path.root}/${var.vagrantfile}"
    }
    post-processor "vagrant-cloud" {
      // access_token = "${var.vagrant_cloud_token}"
      box_tag = "${var.vm_box_provider}/${var.vm_name}"
      version = var.vm_version
    }
  }
}
