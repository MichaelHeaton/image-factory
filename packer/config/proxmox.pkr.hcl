# Shared Proxmox builder configuration
# This file contains reusable Proxmox connection settings and common configurations

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
  default     = ""
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API Token ID"
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API Token Secret"
  sensitive   = true
  default     = ""
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = ""
}

variable "proxmox_storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "vmdks"
}

variable "proxmox_network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "proxmox_iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool for ISO files"
  default     = "isos"
}

locals {
  # Read from environment variables if variables are empty
  # Environment variables take precedence over defaults
  proxmox_url_final           = var.proxmox_url != "" ? var.proxmox_url : (try(env("PROXMOX_URL"), ""))
  proxmox_api_token_id_final  = var.proxmox_api_token_id != "" ? var.proxmox_api_token_id : (try(env("PROXMOX_API_TOKEN_ID"), ""))
  proxmox_api_token_secret_final = var.proxmox_api_token_secret != "" ? var.proxmox_api_token_secret : (try(env("PROXMOX_API_TOKEN_SECRET"), ""))
  proxmox_node_final          = var.proxmox_node != "" ? var.proxmox_node : (try(env("PROXMOX_NODE"), ""))
  proxmox_storage_pool_final  = var.proxmox_storage_pool != "" ? var.proxmox_storage_pool : (try(env("PROXMOX_STORAGE_POOL"), "vmdks"))
  proxmox_network_bridge_final = var.proxmox_network_bridge != "" ? var.proxmox_network_bridge : (try(env("PROXMOX_NETWORK_BRIDGE"), "vmbr0"))
  proxmox_iso_storage_pool_final = var.proxmox_iso_storage_pool != "" ? var.proxmox_iso_storage_pool : (try(env("PROXMOX_ISO_STORAGE_POOL"), "isos"))
}

