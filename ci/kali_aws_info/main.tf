##################################################
## NOTE
# if you are a person that does IaC (Infrastructure as Code)
#   for a living then please don't be mad at me for not following
#   convention of breaking out this file into multiple files
#   (i.e. variables.tf and output.tf) it is easier to showcase
#   at conferences and it does very little, so that is why I have
#   it all in one file.
variable "aws_access_key" {
  description   = "The aws access key to access your account."
  type          = string
}

variable "aws_secret_key" {
  description   = "The aws secret key to access your account."
  type          = string
}

variable "aws_region" {
  description   = "The aws region to access your account."
  type          = string
}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.aws_region
}

data "aws_ami" "kali_linux" {
  most_recent = true

  # Kali Linux's owner id (found with https://stackoverflow.com/questions/47467593/how-am-i-supposed-to-get-the-owner-id-of-an-aws-market-place-ami)
  owners = ["679593333241"]

}

output "kali_ami_id" {
  value = data.aws_ami.kali_linux.id
}
