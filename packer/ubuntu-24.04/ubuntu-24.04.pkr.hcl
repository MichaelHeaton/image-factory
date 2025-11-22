packer {
  required_version = ">= 1.12.0"
  required_plugins {
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.1"
    }
  }
}

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
  description = "Proxmox storage pool"
  default     = "disk-image-nfs-nas02"
}

variable "proxmox_network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "vm_cpu_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "VM memory in MB"
  default     = 2048
}

variable "vm_disk_size" {
  type        = string
  description = "VM disk size (e.g., '40G')"
  default     = "40G"
}

variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "packer"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning (temporary)"
  sensitive   = true
  default     = "packer"
}

variable "template_name" {
  type        = string
  description = "Template name in Proxmox"
  default     = "ubuntu-24.04-hardened"
}

variable "template_description" {
  type        = string
  description = "Template description"
  default     = "Security-hardened Ubuntu 24.04 LTS Server"
}

locals {
  # Read from environment variables if variables are empty
  proxmox_url_final           = var.proxmox_url != "" ? var.proxmox_url : (try(env("PROXMOX_URL"), ""))
  proxmox_api_token_id_final  = var.proxmox_api_token_id != "" ? var.proxmox_api_token_id : (try(env("PROXMOX_API_TOKEN_ID"), ""))
  proxmox_api_token_secret_final = var.proxmox_api_token_secret != "" ? var.proxmox_api_token_secret : (try(env("PROXMOX_API_TOKEN_SECRET"), ""))
  proxmox_node_final          = var.proxmox_node != "" ? var.proxmox_node : (try(env("PROXMOX_NODE"), ""))
  proxmox_storage_pool_final  = var.proxmox_storage_pool != "" ? var.proxmox_storage_pool : (try(env("PROXMOX_STORAGE_POOL"), "local-lvm"))
  proxmox_network_bridge_final = var.proxmox_network_bridge != "" ? var.proxmox_network_bridge : (try(env("PROXMOX_NETWORK_BRIDGE"), "vmbr0"))
}

source "proxmox-iso" "ubuntu-24-04" {
  proxmox_url              = local.proxmox_url_final
  username                 = local.proxmox_api_token_id_final
  token                    = local.proxmox_api_token_secret_final
  insecure_skip_tls_verify = false
  node                     = local.proxmox_node_final

  vm_name         = var.template_name
  template_name   = var.template_name
  template_description = var.template_description

  boot_iso {
    iso_file         = "iso-nfs:iso/ubuntu-24.04.3-live-server-amd64.iso"
    iso_storage_pool = "iso-nfs"
    type             = "ide"
    unmount          = true
  }

  qemu_agent = true

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = var.vm_disk_size
    storage_pool = local.proxmox_storage_pool_final
    type         = "scsi"
    cache_mode   = "writeback"
  }

  network_adapters {
    bridge   = local.proxmox_network_bridge_final
    model    = "virtio"
    vlan_tag = ""
  }

  memory = var.vm_memory
  cores  = var.vm_cpu_cores

  cpu_type    = "host"
  os          = "l26"
  bios        = "seabios"
  machine     = "q35"

  # Boot order: Disk first, then CD-ROM (for template, disk should boot first)
  # During build, Packer will handle booting from ISO
  boot = "order=virtio0;ide2"

  # Boot command for Ubuntu 24.04 autoinstall (BIOS/SeaBIOS)
  boot_command = [
    "c<wait5>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\"",
    "<enter><wait10>",
    "initrd /casper/initrd",
    "<enter><wait10>",
    "boot",
    "<enter>"
  ]

  boot_wait = "5s"
  boot_key_interval = "100ms"

  # Use http_content to serve user-data and meta-data for autoinstall
  http_content = {
    "/meta-data" = file("${path.root}/http/meta-data")
    "/user-data" = file("${path.root}/http/user-data")
  }

  # Wait for VM to be fully running before sending boot commands
  onboot = false

  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = "45m"
  ssh_handshake_attempts = 100

  cloud_init              = false
}

build {
  name = "ubuntu-24.04-hardened"

  sources = ["source.proxmox-iso.ubuntu-24-04"]

  provisioner "ansible" {
    user                   = var.ssh_username
    galaxy_file            = "${path.root}/../../ansible/linux-requirements.yml"
    galaxy_force_with_deps = true
    playbook_file          = "${path.root}/../../ansible/linux-playbook.yml"
    roles_path             = "${path.root}/../../ansible/roles"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../../ansible/ansible.cfg",
      "ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3"
    ]
    extra_arguments = [
      "--extra-vars", "display_skipped_hosts=false",
      "--extra-vars", "build_username=${var.ssh_username}",
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Build completed: ${var.template_name}'"
    ]
  }
}

