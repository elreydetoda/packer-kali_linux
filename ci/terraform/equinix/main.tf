##################################################
## NOTE
# if you are a person that does IaC (Infrastructure as Code)
#   for a living then please don't be mad at me for not following
#   convention of breaking out this file into multiple files
#   (i.e. variables.tf and output.tf) it is easier to showcase
#   at conferences and it does very little, so that is why I have
#   it all in one "big" file.

##################################################
## backend is where your state file lives
terraform {
  backend "remote" {
    organization = "personal_projects_e"

    workspaces {
      name = "packer-kali_linux"
    }
  }
}

##################################################
## Variables that are getting inputted (i.e. variables.tf)
#   set the PACKET_AUTH_TOKEN env variable for auth
#   or the auth_token is required
variable "auth_token" {
  description = "The auth token for the account"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "The ID of the project the device (server) belongs to."
  type        = string
}

##################################################

# NOTE: this needs to be a baremetal host
#   or else packer won't work
#   https://deploy.equinix.com/developers/os-compatibility/
#   https://deploy.equinix.com/developers/api/metal#tag/OperatingSystems
variable "provision_plan" {
  description = "The type of the device (server) getting assigned."
  type        = string
  default     = "c3.small.x86"
}

##################################################
##  Packet server provisioning
# defining the packet provider
provider "equinix" {
  auth_token = var.auth_token
}

locals {
  # variables that start with v = virtualbox/vmware
  # variables that start with q = qemu
  v_server_hostname = "packer-build-box-v"
  q_server_hostname = "packer-build-box-qemu"
  # windows_server_hostname = "packer-build-box-windows"
}

# querying current ip address, so it is able to only whitelist
#   this ip address for incoming connections
# data "http" "current_ip" {
#   url = "https://api.ipify.org/?format=json"
# }

# querying for LTS based on server OS and type
data "equinix_metal_operating_system" "ubuntu_lts" {
  distro           = "ubuntu"
  version          = "22.04"
  provisionable_on = var.provision_plan
}

# TODO: add windows support
# data "equinix_metal_operating_system" "windows" {
#   distro           = "windows"
#   version          = "2022"
#   provisionable_on = var.provision_plan
# }

# provisioning the actual server based on above info
resource "equinix_metal_device" "v_packer_build_server" {
  hostname         = local.v_server_hostname
  project_id       = var.project_id
  operating_system = data.equinix_metal_operating_system.ubuntu_lts.id
  plan             = var.provision_plan
  facilities       = ["any"]
  billing_cycle    = "hourly"
  tags = [
    "virtualbox-iso", "vmware"
  ]

}
resource "equinix_metal_device" "q_packer_build_server" {
  hostname         = local.q_server_hostname
  project_id       = var.project_id
  operating_system = data.equinix_metal_operating_system.ubuntu_lts.id
  plan             = var.provision_plan
  facilities       = ["any"]
  billing_cycle    = "hourly"
  tags = [
    "qemu"
  ]

}

# TODO: add windows support
# resource "equinix_metal_device" "windows_packer_build_server" {
#   hostname         = local.windows_server_hostname
#   project_id       = var.project_id
#   operating_system = data.metal_operating_system.windows.id
#   plan             = var.provision_plan
#   facilities       = "any"
#   billing_cycle    = "hourly"
#   tags = [
#     "windows"
#   ]

# }

##################################################
## Variables that are getting outputted
# outputing server ip address, so scripts are able
#   to reference it
output "v_server_ip" {
  value = equinix_metal_device.v_packer_build_server.access_public_ipv4
}

output "q_server_ip" {
  value = equinix_metal_device.q_packer_build_server.access_public_ipv4
}

# TODO: add windows support
# output "windows_server_ip" {
#   value = equinix_metal_device.windows_packer_build_server.access_public_ipv4
# }

# outputing your ip address, so scripts are able
#   to reference it
# output "current_ip" {
#   value = jsondecode(data.http.current_ip.body).ip
# }
##################################################

terraform {
  required_providers {
    # http = {
    #   source = "hashicorp/http"
    # }
    equinix = {
      source  = "equinix/equinix"
      version = "1.13.0"
    }
  }
  required_version = ">= 1.0"
}