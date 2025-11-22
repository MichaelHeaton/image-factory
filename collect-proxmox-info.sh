#!/bin/bash
set -euo pipefail

# Script to collect comprehensive Proxmox cluster information
# This data will be used for Terraform import and configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/packer"
ENV_FILE="${PACKER_DIR}/.env"
OUTPUT_DIR="${SCRIPT_DIR}/../specs-homelab/proxmox-discovery"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_section() {
    echo -e "${BLUE}[SECTION]${NC} $1"
}

# Load environment variables
if [ ! -f "${ENV_FILE}" ]; then
    echo "Error: .env file not found at ${ENV_FILE}"
    exit 1
fi

source "${ENV_FILE}"

# Verify required variables
if [ -z "${PROXMOX_URL:-}" ] || [ -z "${PROXMOX_API_TOKEN_ID:-}" ] || [ -z "${PROXMOX_API_TOKEN_SECRET:-}" ]; then
    echo "Error: Required Proxmox environment variables not set"
    exit 1
fi

PROXMOX_BASE_URL="${PROXMOX_URL%/api2/json}"
AUTH_HEADER="Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"
print_info "Output directory: ${OUTPUT_DIR}"

# Function to fetch and save JSON data
fetch_and_save() {
    local endpoint=$1
    local filename=$2
    local description=$3

    print_info "Fetching ${description}..."
    local response=$(curl -k -s -H "${AUTH_HEADER}" "${PROXMOX_BASE_URL}${endpoint}")

    # Check if response is valid JSON and not an error
    if echo "$response" | python3 -m json.tool > /dev/null 2>&1; then
        echo "$response" | python3 -m json.tool > "${OUTPUT_DIR}/${filename}"
        print_info "  ✓ Saved to ${filename}"
    else
        echo "$response" > "${OUTPUT_DIR}/${filename}.raw"
        print_info "  ⚠ Saved raw response to ${filename}.raw"
    fi
}

# Function to fetch and save as text
fetch_and_save_text() {
    local endpoint=$1
    local filename=$2
    local description=$3

    print_info "Fetching ${description}..."
    curl -k -s -H "${AUTH_HEADER}" "${PROXMOX_BASE_URL}${endpoint}" > "${OUTPUT_DIR}/${filename}"
    print_info "  ✓ Saved to ${filename}"
}

print_section "=== Proxmox Cluster Discovery ==="
echo ""

# 1. Cluster Information
print_section "1. Cluster Information"
fetch_and_save "/api2/json/cluster/status" "01-cluster-status.json" "cluster status"
fetch_and_save "/api2/json/cluster/config/nodes" "02-cluster-nodes.json" "cluster nodes"
fetch_and_save "/api2/json/cluster/config/totem" "03-cluster-totem.json" "cluster totem config"
fetch_and_save "/api2/json/cluster/options" "04-cluster-options.json" "cluster options"
echo ""

# 2. Nodes
print_section "2. Nodes"
fetch_and_save "/api2/json/nodes" "05-nodes-list.json" "nodes list"

# Get detailed info for each node
NODES=$(curl -k -s -H "${AUTH_HEADER}" "${PROXMOX_BASE_URL}/api2/json/nodes" | python3 -c "import sys, json; nodes = json.load(sys.stdin)['data']; print(' '.join([n['node'] for n in nodes]))" 2>/dev/null || echo "GPU01 NUC01 NUC02")

for node in $NODES; do
    print_info "Fetching details for node: ${node}"
    fetch_and_save "/api2/json/nodes/${node}/status" "06-node-${node}-status.json" "node ${node} status"
    fetch_and_save "/api2/json/nodes/${node}/capabilities/qemu" "07-node-${node}-qemu-capabilities.json" "node ${node} QEMU capabilities"
    fetch_and_save "/api2/json/nodes/${node}/capabilities/lxc" "08-node-${node}-lxc-capabilities.json" "node ${node} LXC capabilities"
done
echo ""

# 3. Storage
print_section "3. Storage"
fetch_and_save "/api2/json/storage" "09-storage-list.json" "storage list"

# Get storage details for each node
for node in $NODES; do
    print_info "Fetching storage for node: ${node}"
    fetch_and_save "/api2/json/nodes/${node}/storage" "10-node-${node}-storage.json" "node ${node} storage"

    # Get detailed info for each storage
    STORAGES=$(curl -k -s -H "${AUTH_HEADER}" "${PROXMOX_BASE_URL}/api2/json/nodes/${node}/storage" | python3 -c "import sys, json; storages = json.load(sys.stdin)['data']; print(' '.join([s['storage'] for s in storages]))" 2>/dev/null || echo "")

    for storage in $STORAGES; do
        fetch_and_save "/api2/json/nodes/${node}/storage/${storage}/status" "11-node-${node}-storage-${storage}-status.json" "storage ${storage} on ${node}"
        fetch_and_save "/api2/json/nodes/${node}/storage/${storage}/content" "12-node-${node}-storage-${storage}-content.json" "storage ${storage} content on ${node}"
    done
done
echo ""

# 4. Networks
print_section "4. Networks"
for node in $NODES; do
    print_info "Fetching networks for node: ${node}"
    fetch_and_save "/api2/json/nodes/${node}/network" "13-node-${node}-network.json" "node ${node} network configuration"
done
echo ""

# 5. VMs and Containers
print_section "5. Virtual Machines and Containers"
for node in $NODES; do
    print_info "Fetching VMs/CTs for node: ${node}"
    fetch_and_save "/api2/json/nodes/${node}/qemu" "14-node-${node}-qemu-vms.json" "QEMU VMs on ${node}"
    fetch_and_save "/api2/json/nodes/${node}/lxc" "15-node-${node}-lxc-containers.json" "LXC containers on ${node}"
done
echo ""

# 6. Access Control
print_section "6. Access Control"
fetch_and_save "/api2/json/access/users" "16-users.json" "users"
fetch_and_save "/api2/json/access/groups" "17-groups.json" "groups"
fetch_and_save "/api2/json/access/roles" "18-roles.json" "roles"
fetch_and_save "/api2/json/access/acl" "19-acl.json" "ACL rules"
fetch_and_save "/api2/json/access/domains" "20-domains.json" "authentication domains"
echo ""

# 7. Pools
print_section "7. Resource Pools"
fetch_and_save "/api2/json/pools" "21-pools.json" "resource pools"
echo ""

# 8. Datacenter Options
print_section "8. Datacenter Configuration"
fetch_and_save "/api2/json/cluster/options" "22-datacenter-options.json" "datacenter options"
echo ""

# 9. Firewall
print_section "9. Firewall Configuration"
fetch_and_save "/api2/json/cluster/firewall/aliases" "23-firewall-aliases.json" "firewall aliases"
fetch_and_save "/api2/json/cluster/firewall/groups" "24-firewall-groups.json" "firewall groups"
fetch_and_save "/api2/json/cluster/firewall/rules" "25-firewall-rules.json" "firewall rules"
fetch_and_save "/api2/json/cluster/firewall/options" "26-firewall-options.json" "firewall options"
echo ""

# 10. HA (High Availability) - if configured
print_section "10. High Availability"
fetch_and_save "/api2/json/cluster/ha/groups" "27-ha-groups.json" "HA groups"
fetch_and_save "/api2/json/cluster/ha/resources" "28-ha-resources.json" "HA resources"
echo ""

# 11. Create summary
print_section "11. Creating Summary"
cat > "${OUTPUT_DIR}/00-SUMMARY.md" << EOF
# Proxmox Cluster Discovery Summary

**Discovery Date:** $(date)
**Proxmox URL:** ${PROXMOX_BASE_URL}
**Cluster:** pve-cluster01

## Files Collected

This directory contains comprehensive information about your Proxmox cluster, organized for Terraform import.

### Structure

- **01-09**: Cluster and node information
- **10-12**: Storage configuration (including NFS shares)
- **13**: Network configuration (including VLANs)
- **14-15**: Virtual machines and containers
- **16-20**: Access control (users, groups, roles, ACLs)
- **21**: Resource pools
- **22**: Datacenter options
- **23-26**: Firewall configuration
- **27-28**: High Availability (if configured)

## Next Steps

1. Review the collected data
2. Use this information to plan Terraform resource imports
3. Create Terraform configuration files in the proxmox repository
4. Import existing resources using: \`terraform import\`

## Important Notes

- Storage names and IDs are case-sensitive
- Network bridge names must match exactly
- VLAN tags are included in network configurations
- NFS shares are in the storage configuration files

EOF

print_info "Summary created: 00-SUMMARY.md"
echo ""

print_section "=== Discovery Complete ==="
print_info "All data saved to: ${OUTPUT_DIR}"
print_info "Review the files and use them to plan your Terraform imports"
echo ""

# Quick stats
if command -v jq &> /dev/null; then
    print_section "Quick Statistics"

    NODE_COUNT=$(cat "${OUTPUT_DIR}/05-nodes-list.json" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "N/A")
    STORAGE_COUNT=$(cat "${OUTPUT_DIR}/09-storage-list.json" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "N/A")
    USER_COUNT=$(cat "${OUTPUT_DIR}/16-users.json" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "N/A")

    echo "  Nodes: ${NODE_COUNT}"
    echo "  Storage: ${STORAGE_COUNT}"
    echo "  Users: ${USER_COUNT}"
    echo ""
fi

