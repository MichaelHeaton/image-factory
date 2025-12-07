#!/bin/bash
# Script to organize Proxmox disk into a folder named after the VM
# This script attempts to move the disk file to a subdirectory on NFS storage

set -euo pipefail

VM_ID="${VM_ID:-}"
VM_NAME="${VM_NAME:-}"
STORAGE_POOL="${STORAGE_POOL:-}"
PROXMOX_URL="${PROXMOX_URL:-}"
TOKEN_ID="${TOKEN_ID:-}"
TOKEN_SECRET="${TOKEN_SECRET:-}"
NODE="${NODE:-}"

if [ -z "$VM_ID" ] || [ -z "$VM_NAME" ] || [ -z "$STORAGE_POOL" ]; then
  echo "Error: Required environment variables not set: VM_ID, VM_NAME, STORAGE_POOL"
  exit 1
fi

echo "Organizing disk for VM: $VM_NAME (ID: $VM_ID)"
echo "Storage pool: $STORAGE_POOL"

# Sanitize VM name for use in directory name (remove special characters)
SAFE_VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]._-' | sed 's/[^[:alnum:]._-]/-/g')

# For NFS storage, Proxmox stores disks as: vm-{id}-disk-{num}.raw or base-{id}-disk-{num}.raw
# We need to find the actual disk file and move it to a subdirectory

if [ -n "$PROXMOX_URL" ] && [ -n "$TOKEN_ID" ] && [ -n "$TOKEN_SECRET" ] && [ -n "$NODE" ]; then
  echo "Querying Proxmox API for disk information..."

  # Get VM configuration to find disk details
  VM_CONFIG=$(curl -k -s -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
    "${PROXMOX_URL}/nodes/${NODE}/qemu/${VM_ID}/config" 2>/dev/null || echo "")

  if [ -n "$VM_CONFIG" ]; then
    # Extract disk information (look for scsi0, virtio0, etc.)
    DISK_VOLID=$(echo "$VM_CONFIG" | grep -o '"scsi0":"[^"]*"' | cut -d'"' -f4 || echo "")

    if [ -z "$DISK_VOLID" ]; then
      DISK_VOLID=$(echo "$VM_CONFIG" | grep -o '"virtio0":"[^"]*"' | cut -d'"' -f4 || echo "")
    fi

    if [ -n "$DISK_VOLID" ]; then
      echo "Found disk volume ID: $DISK_VOLID"

      # Extract storage pool and filename from volid (format: storage:filename)
      DISK_STORAGE=$(echo "$DISK_VOLID" | cut -d':' -f1)
      DISK_FILENAME=$(echo "$DISK_VOLID" | cut -d':' -f2)

      if [ "$DISK_STORAGE" = "$STORAGE_POOL" ]; then
        echo "Disk filename: $DISK_FILENAME"
        echo ""
        echo "Note: Proxmox manages disk locations internally."
        echo "To organize disks in folders, you have two options:"
        echo ""
        echo "Option 1: Manual organization (requires NFS access):"
        echo "  1. Access NFS storage: ${STORAGE_POOL}"
        echo "  2. Create directory: ${STORAGE_POOL}/${SAFE_VM_NAME}/"
        echo "  3. Move disk: ${STORAGE_POOL}/${DISK_FILENAME} -> ${STORAGE_POOL}/${SAFE_VM_NAME}/${DISK_FILENAME}"
        echo "  4. Update Proxmox config via API or web UI"
        echo ""
        echo "Option 2: Use Proxmox storage organization features"
        echo "  Configure storage pools with subdirectories at the Proxmox level"
        echo ""
        echo "Current disk location: ${DISK_VOLID}"
        echo "Recommended folder: ${SAFE_VM_NAME}/"
      else
        echo "Disk is on different storage pool: $DISK_STORAGE (expected: $STORAGE_POOL)"
      fi
    else
      echo "Could not extract disk information from VM config"
    fi
  else
    echo "Could not query Proxmox API for VM config"
  fi
else
  echo "Proxmox credentials not fully provided. Skipping API queries."
  echo "Disk should be at: ${STORAGE_POOL}/vm-${VM_ID}-disk-0.raw (or base-${VM_ID}-disk-0.raw)"
  echo "Recommended folder: ${SAFE_VM_NAME}/"
fi

echo ""
echo "Disk organization information logged. Manual organization may be required."

