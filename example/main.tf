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

module "k3s" {
  source                      = "../"
  authorized_keys_file        = "~/.ssh/id_rsa.pub"
  authorized_private_key_file = "~/.ssh/id_rsa"

  #Support node if none specified installs onto entry point node
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

  # CPU type for all nodes; "host" for max perf if all PVE nodes are compatible
  cpu_type = "x86-64-v2-AES"

  # Register masters as Proxmox HA resources (group must already exist)
  # ha_group = "k3s-ha"

  # Guard created VMs against accidental GUI changes
  protection = false

  # Enabling this setting disables the MariaDB support instance for the cluster.
  # Changing this will trigger a cluster rebuild
  # The main advantage of enabling embedded etcd is the cluster no longer has a single point of failure. But can increase resource usage.
  cluster_enable_embedded_etcd = true

  # Optionally pin the k3s version (empty = current stable channel)
  # k3s_version = "v1.37.0+k3s1"

  # Support node settings
  support_node_settings = {
    target_node = "pve-prd0"
    # DB related settings are ignored when cluster_enable_embedded_etcd = true
    # If using embedded etcd the resources here should be dramatically reduced as Nginx is the main process running.
    # Conversely the storage and specs for the control plane nodes should be increased.
    cores          = 2
    sockets        = 1
    memory         = 1024
    storage_id     = "pve-ssd"
    disk_size      = "16G"
    user           = "support"
    network_tag    = -1
    db_name        = "k3s"
    db_user        = "k3s"
    network_bridge = "vmbr0"
  }

  # Disable default traefik and servicelb installs for metallb and traefik 2
  k3s_disable_components = [
    "traefik",
    "servicelb"
  ]
  # 10.10.2.1 - 10.10.2.6	(6 available IPs for nodes)
  control_plane_subnet = "10.10.2.0/29"

  # These are not rolled as a pool but individually.
  master_nodes = [
    {
      target_node = "pve-prd0"
      cores       = 2
      sockets     = 1
      memory      = 2048
      storage_id  = "pve-ssd"
      # Set disk_size much higher if using embedded etcd
      disk_size      = "240G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    },
    {
      target_node = "pve-prd1"
      cores       = 2
      sockets     = 1
      memory      = 2048
      storage_id  = "pve-ssd"
      # Set disk_size much higher if using embedded etcd
      disk_size      = "240G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    },
    {
      target_node = "pve-prd2"
      cores       = 2
      sockets     = 1
      memory      = 2048
      storage_id  = "pve-ssd"
      # Set disk_size much higher if using embedded etcd
      disk_size      = "240G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  ]
  node_pools = [
    {
      # 10.10.2.9 - 10.10.2.14 (6 available IPs for nodes)
      subnet = "10.10.2.8/29"

      target_node = "pve-prd0"
      size        = 1
      node_pool_settings = {
        name           = "pool0"
        taints         = []
        cores          = 8
        sockets        = 1
        memory         = 8192
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additional_storage = {
          storage_id = "pve-hdd"
          disk_size  = "3500G"
        }
      }
    },
    {
      # 10.10.2.17 - 10.10.2.22 (6 available IPs for nodes)
      subnet = "10.10.2.16/29"

      target_node = "pve-prd1"
      size        = 1
      node_pool_settings = {
        name           = "pool1"
        taints         = []
        cores          = 8
        sockets        = 1
        memory         = 10240
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additional_storage = {
          storage_id = "pve-hdd"
          disk_size  = "3500G"
        }
      }
    },
    {
      # 10.10.2.25 - 10.10.2.30 (6 available IPs for nodes)
      subnet = "10.10.2.24/29"

      target_node = "pve-prd2"
      size        = 1
      node_pool_settings = {
        name           = "pool2"
        taints         = []
        cores          = 8
        sockets        = 1
        memory         = 10240
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additional_storage = {
          storage_id = "pve-hdd"
          disk_size  = "3500G"
        }
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
