
resource "terraform_data" "cluster_enable_embedded_etcd" {
  input = var.cluster_enable_embedded_etcd
}

locals {
  support_node_settings = var.support_node_settings
  support_node_ip       = cidrhost(var.control_plane_subnet, 0)
}

locals {
  lan_subnet_cidr_bitnum = split("/", var.lan_subnet)[1]
}

resource "proxmox_vm_qemu" "k3s-support" {
  target_node = length(var.proxmox_support_node) == 0 ? var.proxmox_node : var.proxmox_support_node
  name        = join("-", [var.cluster_name, "support"])

  clone = var.node_template

  pool   = var.proxmox_resource_pool
  onboot = true

  # cores = 2
  cores   = local.support_node_settings.cores
  sockets = local.support_node_settings.sockets
  memory  = local.support_node_settings.memory
  scsihw  = "virtio-scsi-pci"
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = local.support_node_settings.storage_id
        }
      }
    }
    # Boot disk
    scsi {
      scsi0 {
        disk {
          replicate = true
          storage   = local.support_node_settings.storage_id
          size      = local.support_node_settings.disk_size
        }
      }
    }
  }

  network {
    bridge    = local.support_node_settings.network_bridge
    link_down = false
    model     = "virtio"
    queues    = 0
    rate      = 0
    tag       = local.support_node_settings.network_tag
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      disks,
      network,
      hagroup,
      hastate
    ]
    replace_triggered_by = [terraform_data.cluster_enable_embedded_etcd]
  }

  os_type = "cloud-init"

  ciuser = local.support_node_settings.user

  ipconfig0 = "ip=${local.support_node_ip}/${local.lan_subnet_cidr_bitnum},gw=${var.network_gateway}"

  sshkeys = file(var.authorized_keys_file)

  connection {
    type        = "ssh"
    user        = local.support_node_settings.user
    host        = local.support_node_ip
    private_key = file(var.authorized_private_key_file)
    agent       = false
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.module}/scripts/install-support-apps.sh.tftpl", {
      root_password      = random_password.support-db-password.result
      k3s_database       = local.support_node_settings.db_name
      k3s_user           = local.support_node_settings.db_user
      k3s_password       = random_password.k3s-master-db-password.result
      http_proxy         = var.http_proxy
      embedded_etcd_init = var.cluster_enable_embedded_etcd
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /tmp/install.sh",
      "sh /tmp/install.sh",
      "rm -r /tmp/install.sh",
    ]
  }
}

resource "random_password" "support-db-password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "random_password" "k3s-master-db-password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "null_resource" "k3s_nginx_config" {

  depends_on = [
    proxmox_vm_qemu.k3s-support
  ]

  triggers = {
    config_change = filemd5("${path.module}/config/nginx.conf.tftpl")
  }

  connection {
    type        = "ssh"
    user        = local.support_node_settings.user
    host        = local.support_node_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/nginx.conf"
    content = templatefile("${path.module}/config/nginx.conf.tftpl", {
      k3s_server_hosts = [for master_node in local.listed_master_nodes :
        "${master_node.ip}:6443"
      ]
      k3s_nodes = concat([for master_node in local.listed_master_nodes : master_node.ip], [for node in local.listed_worker_nodes : node.ip])
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx.service",
    ]
  }
}
