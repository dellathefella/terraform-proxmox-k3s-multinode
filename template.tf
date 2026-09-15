locals {
  # Effective template VM ID: user-provided, or the module-built template when
  # template_image is used. coalesce/try keep this null-safe before the
  # template resource exists.
  effective_template_vm_id = coalesce(
    var.template_vm_id,
    try(proxmox_virtual_environment_vm.k3s_template[0].vm_id, null)
  )
}

resource "proxmox_download_file" "k3s_template_image" {
  count = var.template_image != null ? 1 : 0

  content_type = "import"
  datastore_id = var.template_image.datastore_id
  node_name    = var.template_image.node_name
  file_name    = var.template_image.file_name
  url          = var.template_image.url
}

resource "proxmox_virtual_environment_vm" "k3s_template" {
  count = var.template_image != null ? 1 : 0

  node_name = var.template_image.node_name
  name      = "${var.cluster_name}-template"
  vm_id     = var.vm_id_start

  template        = true
  stop_on_destroy = true

  agent {
    enabled = false
  }

  cpu {
    cores = 2
    type  = var.cpu_type
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.template_image.datastore_id
    import_from  = proxmox_download_file.k3s_template_image[0].id
    interface    = "scsi0"
    size         = var.template_image.disk_size
  }

  initialization {
    datastore_id = var.template_image.datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.template_image.user
      keys     = [trimspace(file(var.authorized_keys_file))]
    }
  }

  network_device {
    bridge = var.template_image.network_bridge
  }

  tags = [var.cluster_name]
}
