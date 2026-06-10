variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region. Must be in your Azure-for-Students allowed regions."
}

variable "prefix" {
  type        = string
  default     = "taskapp"
  description = "Prefix for resource names; combined with a random suffix for uniqueness."
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Number of nodes in the AKS default pool (keep at 1 to save student credit)."
}

variable "node_size" {
  type        = string
  default     = "Standard_B2ms"
  description = "VM size for AKS nodes. B2ms = 2 vCPU / 8 GB, cheap and enough for this demo."
}
