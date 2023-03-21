# The public SSH key to use
variable "public_key_path" {
  description = "Public SSH Key to use (e.g: ~/.ssh/telemachus.pub)"
  default = "~/.ssh/telemachus.pub"
}

# Resource Group Location
variable "resource_group_location" {
  default       = "eastus"
  description   = "Location of the resource group."
}