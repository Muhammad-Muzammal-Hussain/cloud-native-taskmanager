# Random suffix so globally-unique names (ACR) don't clash with other students.
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# ---------------------------------------------------------------------------
# Resource Group (lab 01/02) - one group holds everything, easy teardown.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg-${random_integer.suffix.result}"
  location = var.location
}

# ---------------------------------------------------------------------------
# Azure Container Registry (private image registry for our app images).
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}acr${random_integer.suffix.result}" # alphanumeric only
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# ---------------------------------------------------------------------------
# Log Analytics workspace + Container Insights (lab 10 - Monitoring).
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law-${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ---------------------------------------------------------------------------
# Azure Kubernetes Service cluster (labs 05/07/08).
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks-${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}-aks"

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.node_size
  }

  # Cluster gets its own managed identity (used below to pull from ACR).
  identity {
    type = "SystemAssigned"
  }

  # Container Insights -> ships metrics/logs to Log Analytics (lab 10).
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}

# ---------------------------------------------------------------------------
# Let the cluster's kubelet identity pull images from our ACR (AcrPull role).
# This is what "az aks update --attach-acr" does, expressed as IaC.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
