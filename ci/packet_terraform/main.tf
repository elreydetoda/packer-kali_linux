##################################################
## NOTE
# if you are a person that does IaC (Infrastructure as Code)
#   for a living then please don't be mad at me for not following
#   convention of breaking out this file into multiple files
#   (i.e. variables.tf and output.tf) it is easier to showcase
#   at conferences and it does very little, so that is why I have
#   it all in one "big" file.

##################################################
## Variables that are getting inputted (i.e. variables.tf)
#   set the PACKET_AUTH_TOKEN env variable for auth
#   or the auth_token is required
variable "auth_token" {
  description   = "The auth token for the account"
  type          = string
}

variable "project_id" {
  description   = "The ID of the project the device (server) belongs to."
  type          = string
}

variable "server_hostname" {
  description   = "The hostname of the device (server) getting assigned."
  type          = string
  default       = "packer-build-box"
}

# NOTE: this needs to be a baremetal host
#   or else packer won't work
variable "provision_plan" {
  description   = "The type of the device (server) getting assigned."
  type          = string
  default       = "baremetal_1"
}

##################################################
##  Packet server provisioning
# defining the packet provider
provider "packet" {
  auth_token = var.auth_token
}

# querying current ip address, so it is able to only whitelist
#   this ip address for incoming connections
data "http" "current_ip" {
  url = "https://ifconfig.co/json"
}

# querying for LTS based on server OS and type
data "packet_operating_system" "ubuntu_lts" {
    distro              = "ubuntu"
    version             = "20.04"
    provisionable_on    = var.provision_plan
}

# provisioning the actual server based on above info
resource "packet_device" "packer_build_server" {
  hostname          = var.server_hostname
  project_id        = var.project_id
  operating_system  = data.packet_operating_system.ubuntu_lts.id
  plan              = var.provision_plan
  facilities        = [ "any" ]
  billing_cycle     = "hourly"

}
##################################################
## Variables that are getting outputted
# outputing server ip address, so scripts are able
#   to reference it
output "server_ip" {
  value = packet_device.packer_build_server.access_public_ipv4
}

# outputing your ip address, so scripts are able
#   to reference it
output "current_ip" {
  value = jsondecode(data.http.current_ip.body).ip
}
##################################################
