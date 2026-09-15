terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }
}

provider "proxmox" {
  # make sure to export PM_API_TOKEN_ID and PM_API_TOKEN_SECRET
  endpoint = "https://10.10.1.100:8006/"
  insecure = true
}

# Topology for 9 identical micro PCs (i5-7500T = 4 cores / 4 threads, 16 GB RAM).
#
#   pve-prd0 : support (1c/1G) + master0 (2c/4G)   [co-located, both light]
#   pve-prd1 : master1 (2c/4G)
#   pve-prd2 : master2 (2c/4G)
#   pve-prd3 : worker pool0 (4c/12G)
#   pve-prd4 : worker pool1 (4c/12G)
#   pve-prd5 : worker pool2 (4c/12G)
#   pve-prd6 : worker pool3 (4c/12G)
#   pve-prd7 : worker pool4 (4c/12G)
#   pve-prd8 : worker pool5 (4c/12G)
#
# 3 masters give an HA embedded-etcd control plane. Each VM leaves ~2-4 GB of
# host RAM for Proxmox itself (cap ZFS ARC if you use ZFS, e.g. set
# zfs_arc_max=2147483648 so the ARC doesn't eat the worker's 12 GB).
#
# NOTE: storage_id / disk_size below are placeholders - set them to your actual
# datastores. etcd (masters) wants SSD; workers can use whatever you have.
module "k3s" {
  source                      = "../"
  authorized_keys_file        = "~/.ssh/id_rsa.pub"
  authorized_private_key_file = "~/.ssh/id_rsa"

  # Numeric VM ID of the debian-13-cloudinit-template (see README template creation)
  template_vm_id = 8003

  # ...or let the module build the template itself (mutually exclusive with template_vm_id):
  # template_image = {
  #   node_name    = "pve-prd0"
  #   datastore_id = "local"
  #   url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  #   file_name    = "debian-13-genericcloud-amd64.qcow2"
  #   disk_size    = 16
  # }

  # support = 900+1, masters = 900+2.., workers after; auto-built template takes 900
  vm_id_start     = 900
  network_gateway = "10.10.1.1"
  lan_subnet      = "10.10.1.1/16"
  cluster_name    = "jdella-com-prd"

  # DNS servers handed to nodes via cloud-init (nodes use static IPs)
  dns_servers = ["10.10.1.1", "1.1.1.1"]

  # All 9 hosts are the same i5-7500T, so host CPU passthrough is safe and fastest.
  cpu_type = "host"

  # Register masters as Proxmox HA resources (group must already exist)
  # ha_group = "k3s-ha"

  # Guard created VMs against accidental GUI changes
  protection = false

  # Floating API VIP (keepalived) across the masters. Free address in the
  # control-plane block (support=.0, masters=.1-.3, VIP=.7).
  api_vip        = "10.10.2.7"
  vrrp_router_id = 51
  vrrp_auth_pass = "k3svip1" # max 8 chars (VRRPv2)

  # Embedded etcd: HA control plane, no MariaDB single point of failure.
  # The support node becomes a near-idle placeholder.
  cluster_enable_embedded_etcd = true

  # Optionally pin the k3s version (empty = current stable channel)
  # k3s_version = "v1.37.0+k3s1"

  # Support node (co-located on pve-prd0 with master0; minimal with embedded etcd)
  support_node_settings = {
    target_node    = "pve-prd0"
    cores          = 1
    sockets        = 1
    memory         = 1024
    storage_id     = "local-lvm"
    disk_size      = "16G"
    user           = "support"
    network_tag    = -1
    db_name        = "k3s"
    db_user        = "k3s"
    network_bridge = "vmbr0"
  }

  # Disable default traefik and servicelb installs (use MetalLB + Traefik 2)
  k3s_disable_components = [
    "traefik",
    "servicelb"
  ]

  # 10.10.2.0/29 -> support .0, masters .1-.3, VIP .7
  control_plane_subnet = "10.10.2.0/29"

  # Control plane: 3 masters on pve-prd0/1/2 (2 cores / 4 GB each)
  master_nodes = [
    {
      target_node    = "pve-prd0"
      cores          = 2
      sockets        = 1
      memory         = 4096
      storage_id     = "local-lvm"
      disk_size      = "48G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    },
    {
      target_node    = "pve-prd1"
      cores          = 2
      sockets        = 1
      memory         = 4096
      storage_id     = "local-lvm"
      disk_size      = "48G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    },
    {
      target_node    = "pve-prd2"
      cores          = 2
      sockets        = 1
      memory         = 4096
      storage_id     = "local-lvm"
      disk_size      = "48G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  ]

  # Workers: one per remaining host (pve-prd3..8), 4 cores / 12 GB each.
  # Each pool is a single node on its own /29 allocation block.
  node_pools = [
    {
      subnet      = "10.10.2.8/29" # worker .9
      target_node = "pve-prd3"
      size        = 1
      node_pool_settings = {
        name           = "pool0"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    },
    {
      subnet      = "10.10.2.16/29" # worker .17
      target_node = "pve-prd4"
      size        = 1
      node_pool_settings = {
        name           = "pool1"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    },
    {
      subnet      = "10.10.2.24/29" # worker .25
      target_node = "pve-prd5"
      size        = 1
      node_pool_settings = {
        name           = "pool2"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    },
    {
      subnet      = "10.10.2.32/29" # worker .33
      target_node = "pve-prd6"
      size        = 1
      node_pool_settings = {
        name           = "pool3"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    },
    {
      subnet      = "10.10.2.40/29" # worker .41
      target_node = "pve-prd7"
      size        = 1
      node_pool_settings = {
        name           = "pool4"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    },
    {
      subnet      = "10.10.2.48/29" # worker .49
      target_node = "pve-prd8"
      size        = 1
      node_pool_settings = {
        name           = "pool5"
        taints         = []
        cores          = 4
        sockets        = 1
        memory         = 12288
        storage_id     = "local-lvm"
        disk_size      = "128G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
      }
    }
  ]
}

output "kubeconfig_path" {
  # Update module name. Here we are using 'k3s'
  value = module.k3s.k3s_kubeconfig_path
}

output "api_endpoint" {
  value = module.k3s.api_endpoint
}
