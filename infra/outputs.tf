output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "acr_login_server" {
  description = "Use this as ACR_LOGIN_SERVER when building/pushing images."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "log_analytics_workspace" {
  value = azurerm_log_analytics_workspace.law.name
}

# Command to fetch kubeconfig after apply:
#   az aks get-credentials -g <rg> -n <aks>
output "get_credentials_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
