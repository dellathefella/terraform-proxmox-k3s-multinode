
output "k3s_db_password" {
  value     = random_password.k3s-mariadb-password.result
  sensitive = true
}

output "k3s_db_name" {
  value = local.support_node_settings.db_name
}

output "k3s_db_user" {
  value = local.support_node_settings.db_user
}

output "k3s_db_host" {
  value = "${local.support_node_ip}:3306"
}

output "root_db_password" {
  value     = random_password.support-user-password.result
  sensitive = true
}

output "support_node_ip" {
  value = local.support_node_ip
}

output "support_node_user" {
  value = local.support_node_settings.user
}

output "k3s_server_token" {
  value     = random_password.k3s-server-token.result
  sensitive = true
}

output "k3s_master_node_ips" {
  value = [
    for master_node in local.listed_master_nodes : master_node.ip
  ]
}

output "api_endpoint" {
  description = "Address the K3s API is reached at (VIP when set, otherwise the first master)."
  value       = local.api_endpoint
}

output "k3s_kubeconfig_path" {
  description = "Path the kubeconfig was written to at apply time (empty when kubeconfig_output_path is disabled). The server address is already rewritten to the API endpoint."
  value       = var.kubeconfig_output_path != "" ? abspath(var.kubeconfig_output_path) : ""
}

output "effective_no_proxy" {
  description = "The full NO_PROXY list exported to nodes: the user's no_proxy plus the pod/service CIDRs, every node subnet and the API VIP."
  value       = local.effective_no_proxy
}

