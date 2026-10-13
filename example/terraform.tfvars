network_gateway = "10.0.0.1"
lan_subnet = "10.0.0.1/8"
control_plane_subnet = "10.0.5.16/29"

master_nodes = [
  {
    target_node    = "opti0"
    cores          = 4
    sockets        = 1
    memory         = 8192
    storage_id     = "local-lvm"
    disk_size      = "48G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
  },
  {
    target_node    = "opti2"
    cores          = 4
    sockets        = 1
    memory         = 8192
    storage_id     = "local-lvm"
    disk_size      = "48G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
  },
  {
    target_node    = "opti3"
    cores          = 4
    sockets        = 1
    memory         = 8192
    storage_id     = "local-lvm"
    disk_size      = "48G"
    user           = "k3s"
    network_bridge = "vmbr0"
    network_tag    = -1
  }
]

node_pools = [
  {
    subnet      = "10.0.5.40/29"
    target_node = "opti5"
    size        = 1
    node_pool_settings = {
      name           = "pool2"
      taints         = []
      cores          = 4
      sockets        = 1
      memory         = 13312
      storage_id     = "local-lvm"
      disk_size      = "128G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  },
  {
    subnet      = "10.0.5.48/29"
    target_node = "opti6"
    size        = 1
    node_pool_settings = {
      name           = "pool3"
      taints         = []
      cores          = 4
      sockets        = 1
      memory         = 13312
      storage_id     = "local-lvm"
      disk_size      = "128G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  },
  {
    subnet      = "10.0.5.56/29"
    target_node = "opti7"
    size        = 1
    node_pool_settings = {
      name           = "pool4"
      taints         = []
      cores          = 4
      sockets        = 1
      memory         = 13312
      storage_id     = "local-lvm"
      disk_size      = "128G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  },
  {
    subnet      = "10.0.5.64/29"
    target_node = "opti8"
    size        = 1
    node_pool_settings = {
      name           = "pool5"
      taints         = []
      cores          = 4
      sockets        = 1
      memory         = 13312
      storage_id     = "local-lvm"
      disk_size      = "128G"
      user           = "k3s"
      network_bridge = "vmbr0"
      network_tag    = -1
    }
  }
]
