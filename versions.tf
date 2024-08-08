terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
    }
  }
}

locals {
  authorized_keyfile = "authorized_keys"
}
