# terraform-proxmox-k3s-multi-node

This is an example project for setting up your own K3s cluster at home.

## Summary

### VMs
This will spin up:

- 1 Support VM with API LoadBalancer and optionally MariaDB K3s database with 2 cores and 8GB of RAM. If embedded etcd only the LoadBalancer is deployed.
- 3 master nodes spread across each PVE host with 2 cores and 2GB of RAM
- 2 node pool with 2 worker nodes each having 8 cores and 10GB of RAM


### Networking

- The support VM will be spun up on nodes `pve-prd0` using at `10.0.6.0`
- The masters VMs will be spun up on nodes `pve-prd0`,`pve-prd1` and `pve-prd2` using at `10.10.2.1-10.10.1.3`
- The masters VMs will be spun up on nodes `pve-prd0`,`pve-prd1` and `pve-prd2` using at `10.10.2.9,10.10.2.17,10.10.2.25`

> Note: To eliminate potential IP clashing with existing computers on your
network, it is **STRONGLY** recommended that you take IPs out of your DHCP server's rotation. Otherwise other computers
in your network may already be using these IPs and that will create conflicts!
Check your router's manual or google it for a step-by-step guide.

## Usage

To run this example, make sure you `cd` to this directory in your terminal,
then
1. Copy your public key to the `authorized_keys` file. In most cases, you
   should be able to do this by running
   `cat ~/.ssh/id_rsa.pub > authorized_keys`.
2. Find your Proxmox API. It should look something like
   `https://192.168.1.200:8006/api2/json`. Once you found it, update the value
   in the `main.tf` file marked as `TODO` in the `provider proxmox` section.
3. Authenticate to the proxmox API **for the current terminal session** by setting the two variables:
  ```bash
  # Update these to be your proxmox user/password.
  # Note that you usually need to keep the @pam at the end of the user.
  export PM_API_TOKEN_ID='root@pam!k3s'
  export PM_API_TOKEN_SECRET="something-something-something-something"
  ```

  > Find other ways to auth to proxmox by reading [the providor's docs](https://github.com/Telmate/terraform-provider-proxmox/blob/master/docs/index.md).
4. Run `terraform init` (only needs to be done the first time)
5. Run `terraform apply`
6. Review the plan. Make sure it is doing what you expect!
7. Enter `yes` in the prompt and wait for your cluster to spin up.
8. Retrieve your kubecontext by running
   `terraform output -raw kubeconfig > config.yaml`
9. Make all your `kubectl` commands work with your cluster for your terminal
   session by running `export KUBECONFIG="config.yaml"`. If you want to add the
   context more perminantly globaly, [refer to the document on managing Kubernetes configs](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#create-a-second-configuration-file).
