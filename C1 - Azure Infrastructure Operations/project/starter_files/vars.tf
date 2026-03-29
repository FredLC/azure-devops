# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MPL-2.0

variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default = "udacity"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "canadacentral"
}

variable "admin_username" {
  description = "The admin username for the VM being created."
  default = "azureuser"
}

variable "admin_password" {
  description = "The password for the VM being created."
  default = "dxz?N#!g@3XXYJNX"
}

variable "vm_count" {
  description = "The number of virtual machines to provision"
  default = 2

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 5
    error_message = "vm_count must be between 1 and 5 to stay within the allowed cost limit."
  }
}