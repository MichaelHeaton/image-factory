#!/bin/bash
# Script to delete old template VM 900 from Proxmox
# Usage: ./delete-old-template.sh

set -e

PROXMOX_HOST="gpu01.specterrealm.com"
VM_ID=900

echo "⚠️  WARNING: This will DELETE template VM 900 from Proxmox!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo "Connecting to Proxmox host..."
ssh root@${PROXMOX_HOST} << EOF
    echo "Stopping VM ${VM_ID} (if running)..."
    qm stop ${VM_ID} || true

    echo "Waiting for VM to stop..."
    sleep 5

    echo "Destroying VM ${VM_ID}..."
    qm destroy ${VM_ID}

    echo "✅ Template VM ${VM_ID} deleted successfully"
EOF

echo ""
echo "✅ Old template deleted. You can now rebuild the template."

