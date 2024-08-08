terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}

provider "proxmox" {
  # make sure to export PM_API_TOKEN_ID and PM_API_TOKEN_SECRET
  pm_tls_insecure = true
  pm_log_enable   = true
  pm_api_url      = "https://10.10.1.100:8006/api2/json"
  pm_timeout      = 600
}

module "k3s" {
  source                      = "git::github.com/dellathefella/terraform-proxmox-k3s-multinode"
  authorized_keys_file        = "~/.ssh/id_rsa.pub"
  authorized_private_key_file = "~/.ssh/id_rsa"
  proxmox_node                = "pve-prd0"

  #Support node if none specified installs onto entry point node
  node_template        = "ubuntu-2204-cloudinit-template"
  network_gateway      = "10.10.1.1"
  lan_subnet           = "10.10.1.1/16"
  cluster_name         = "jdella-com-prd"
  # Enabling this setting disables the MariaDB support instance for the cluster.
  # Changing this will trigger a cluster rebuild
  # The main advantage of enabling embedded etcd is the cluster no longer has a single point of failure. But can increase resource usage.
  cluster_enable_embedded_etcd = true

  # Support node settings
  proxmox_support_node = "pve-prd0"
  support_node_settings = {
    # DB related settings are ignored when cluster_enable_embedded_etcd = true
    # If using embedded etcd the resources here should be dramatically reduced as Nginx is the main process running.
    # Conversely the storage and specs for the control plane nodes should be increased.
    cores        = 2
    sockets      = 1
    memory       = 1024
    storage_type = "scsi"
    storage_id   = "pve-ssd"
    disk_size    = "16G"
    storage_type = "scsi"
    user         = "support"
    network_tag  = -1
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
    target_node  = "pve-prd0"
    cores        = 2
    sockets      = 1
    memory       = 2048
    storage_type = "scsi"
    storage_id   = "pve-ssd"
    user         = "k3s"
    # Set disk_size much higher if using embedded etcd
    disk_size      = "240G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
    user           = "k3s"
  },
  {
    target_node  = "pve-prd1"
    cores        = 2
    sockets      = 1
    memory       = 2048
    storage_type = "scsi"
    storage_id   = "pve-ssd"
    user         = "k3s"
    # Set disk_size much higher if using embedded etcd
    disk_size      = "240G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
    user           = "k3s"
  },
  {
    target_node  = "pve-prd2"
    cores        = 2
    sockets      = 1
    memory       = 2048
    storage_type = "scsi"
    storage_id   = "pve-ssd"
    user         = "k3s"
    # Set disk_size much higher if using embedded etcd
    disk_size      = "240G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
    user           = "k3s"
  }
  ]
  node_pools = [
    {
      # 10.10.2.1 - 10.10.2.6	 (6 available IPs for nodes)
      subnet = "10.10.2.8/29"

      target_node = "pve-prd0"
      size        = 1
      node_pool_settings = {
        name           = "pool0",
        taints         = [""]
        cores          = 8
        sockets        = 1
        memory         = 8192
        storage_type   = "scsi"
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additonal_storage = {
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
        name           = "pool1",
        taints         = [""]
        cores          = 8
        sockets        = 1
        memory         = 10240
        storage_type   = "scsi"
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additonal_storage = {
          storage_id = "pve-hdd"
          disk_size  = "3500G"
        }
      },
    },
    {
      # 10.10.2.25 - 10.10.2.30 (6 available IPs for nodes)
      subnet = "10.10.2.24/29"

      target_node = "pve-prd2"
      size        = 1
      node_pool_settings = {
        name           = "pool2",
        taints         = [""]
        cores          = 8
        sockets        = 1
        memory         = 10240
        storage_type   = "scsi"
        storage_id     = "pve-ssd"
        disk_size      = "1000G"
        user           = "k3s"
        network_bridge = "vmbr0"
        network_tag    = -1
        additonal_storage = {
          storage_id = "pve-hdd"
          disk_size  = "3500G"
        }
      }
    }
  ]
}

output "kubeconfig" {
  # Update module name. Here we are using 'k3s'
  value     = module.k3s.k3s_kubeconfig
  sensitive = true
}