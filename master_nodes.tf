locals {
  listed_master_nodes = flatten([
    for i, master_node in var.master_nodes : merge(master_node, {
        name = "${var.cluster_name}-master-${i}"
        i  = i
        ip = cidrhost(var.control_plane_subnet, i + 1)})
      ])

  mapped_master_nodes = {
    for node in local.listed_master_nodes : "${node.name}" => node
  }

}

resource "random_password" "k3s-server-token" {
  length           = 32
  special          = false
  override_special = "_%@"
}

resource "proxmox_vm_qemu" "k3s-master" {
  depends_on = [
    proxmox_vm_qemu.k3s-support,
  ]

  for_each = local.mapped_master_nodes

  target_node = each.value.target_node
  name        = each.value.name
  clone = var.node_template
  pool = var.proxmox_resource_pool
  onboot = true
  cores   = each.value.cores
  sockets = each.value.sockets
  memory  = each.value.memory
  scsihw = "virtio-scsi-pci"
  disks {
    ide{
      ide2 {
        cloudinit {
          storage = each.value.storage_id
        }
      }
    }
    # Boot disk
    scsi{
      scsi0 {
        disk {
          storage = each.value.storage_id
          size    = each.value.disk_size
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
  }

  os_type = "cloud-init"

  ciuser = each.value.user

  ipconfig0 = "ip=${each.value.ip}/${local.lan_subnet_cidr_bitnum},gw=${var.network_gateway}"

  sshkeys = file(var.authorized_keys_file)

  connection {
    type = "ssh"
    user = each.value.user
    host = each.value.ip
    private_key = file(var.authorized_private_key_file)
    agent = false
  }

  provisioner "remote-exec" {
    # Any additional node past the first one sleeps for extra time to ensure etcd can be bootstrapped in time.
    inline = ["sleep ${(each.value.i+1)*10}",
      templatefile("${path.module}/scripts/install-k3s-server.sh.tftpl", {
        mode         = "server"
        tokens       = [random_password.k3s-server-token.result]
        alt_names    = concat([local.support_node_ip], var.api_hostnames)
        # Skip first host for server hosts if embedded etcd is turned on
        server_hosts = var.cluster_enable_embedded_etcd == true && each.value.i != 0 ? ["https://${local.listed_master_nodes[0].ip}:6443"] : []
        node_taints  = ["CriticalAddonsOnly=true:NoExecute"]
        disable      = var.k3s_disable_components
        # Datastores are not enabled if embedded etcd is enabled
        datastores = var.cluster_enable_embedded_etcd == false ? [{
          host     = "${local.support_node_ip}:3306"
          name     = "k3s"
          user     = "k3s"
          password = random_password.k3s-master-db-password.result
        }] : []
        http_proxy  = var.http_proxy
        # Master nodes do not have extra storage
        extra_storage_enable = false
        # Embedded etcd init if first control plane node and embedded etcd is enable. 
        embedded_etcd_init = each.value.i == 0 && var.cluster_enable_embedded_etcd == true ? true : false
      })
    ,"sleep 5"]
  }
}

data "external" "kubeconfig" {
  depends_on = [
    proxmox_vm_qemu.k3s-support,
    proxmox_vm_qemu.k3s-master
  ]

  program = [
    "/usr/bin/ssh",
    "-o UserKnownHostsFile=/dev/null",
    "-o StrictHostKeyChecking=no",
    "${local.listed_master_nodes[0].user}@${local.listed_master_nodes[0].ip}",
    "echo '{\"kubeconfig\":\"'$(sudo cat /etc/rancher/k3s/k3s.yaml | base64)'\"}'"
  ]
}
