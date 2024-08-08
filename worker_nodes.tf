locals {
  listed_worker_nodes = flatten([
    for pool in var.node_pools :
    [
      for i in range(pool.size) :
      merge(pool.node_pool_settings, {
        target_node = pool.target_node
        i           = i
        ip          = cidrhost(pool.subnet, i)
      })
    ]
  ])

  mapped_worker_nodes = {
    for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node
  }

}

resource "proxmox_vm_qemu" "k3s-worker" {
  depends_on = [
    proxmox_vm_qemu.k3s-support,
    proxmox_vm_qemu.k3s-master,
  ]

  for_each = local.mapped_worker_nodes

  target_node = each.value.target_node
  name        = "${var.cluster_name}-${each.key}"

  clone = var.node_template

  pool   = var.proxmox_resource_pool
  onboot = true

  cores   = each.value.cores
  sockets = each.value.sockets
  memory  = each.value.memory
  scsihw  = "virtio-scsi-pci"
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = each.value.storage_id
        }
      }
    }
    # Boot disk
    scsi {
      scsi0 {
        disk {
          storage = each.value.storage_id
          size    = each.value.disk_size
        }
      }
      dynamic "scsi1" {
        for_each = each.value.additonal_storage != null ? [each.value.additonal_storage] : []
        content {
          disk {
            storage = scsi1.value.storage_id
            size    = scsi1.value.disk_size
          }
        }
      }
    }
  }

  network {
    bridge    = each.value.network_bridge
    firewall  = true
    link_down = false
    model     = "virtio"
    queues    = 0
    rate      = 0
    tag       = each.value.network_tag
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

  ciuser = each.value.user

  ipconfig0 = "ip=${each.value.ip}/${local.lan_subnet_cidr_bitnum},gw=${var.network_gateway}"

  sshkeys = file(var.authorized_keys_file)

  connection {
    type        = "ssh"
    user        = each.value.user
    host        = each.value.ip
    private_key = file(var.authorized_private_key_file)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = ["sleep 5",
      templatefile("${path.module}/scripts/install-k3s-server.sh.tftpl", {
        mode                 = "agent"
        tokens               = [random_password.k3s-server-token.result]
        alt_names            = []
        disable              = []
        server_hosts         = ["https://${local.support_node_ip}:6443"]
        node_taints          = each.value.taints
        datastores           = []
        http_proxy           = var.http_proxy
        extra_storage_enable = each.value.additonal_storage != null ? true : false
        # This is when initializing etcd for the first time. It is always false on worker nodes.
        embedded_etcd_init = false
      })
    , "sleep 5"]
  }
}
