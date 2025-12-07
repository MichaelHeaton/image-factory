#!/bin/bash
# Standalone automated build script for cron or manual execution
# This script builds a new template and cleans up old ones

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables from .env file
ENV_FILE="${SCRIPT_DIR}/packer/.env"
if [ ! -f "$ENV_FILE" ]; then
    print_error "Environment file not found: $ENV_FILE"
    exit 1
fi

print_info "Loading environment variables..."
set -a
source "$ENV_FILE"
set +a

# Validate required variables
REQUIRED_VARS=("PROXMOX_URL" "PROXMOX_API_TOKEN_ID" "PROXMOX_API_TOKEN_SECRET" "PROXMOX_NODE")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_error "Required variable not set: $var"
        exit 1
    fi
done

# Configuration
VM_ID="${VM_ID:-900}"
TEMPLATE_PATTERN="${TEMPLATE_PATTERN:-ubuntu-24.04-hardened-}"
KEEP_COUNT="${KEEP_COUNT:-1}"

print_info "Starting automated template build"
print_info "Template pattern: ${TEMPLATE_PATTERN}*"
print_info "VM ID: ${VM_ID}"
print_info "Keep count: ${KEEP_COUNT}"

# Build new template
print_info "Building new template..."
cd packer/ubuntu-24.04

if packer build \
    -var "proxmox_url=${PROXMOX_URL}" \
    -var "proxmox_api_token_id=${PROXMOX_API_TOKEN_ID}" \
    -var "proxmox_api_token_secret=${PROXMOX_API_TOKEN_SECRET}" \
    -var "proxmox_node=${PROXMOX_NODE}" \
    -var "proxmox_storage_pool=${PROXMOX_STORAGE_POOL:-vmdks}" \
    -var "proxmox_network_bridge=${PROXMOX_NETWORK_BRIDGE:-vmbr0}" \
    -var "vm_id=${VM_ID}" \
    ubuntu-24.04.pkr.hcl; then

    print_info "Template build completed successfully"

    # Cleanup old templates
    print_info "Cleaning up old templates..."
    cd "$SCRIPT_DIR"

    export PROXMOX_URL TOKEN_ID="${PROXMOX_API_TOKEN_ID}" TOKEN_SECRET="${PROXMOX_API_TOKEN_SECRET}"
    export NODE="${PROXMOX_NODE}" TEMPLATE_PATTERN KEEP_COUNT DRY_RUN="false"

    if ./scripts/cleanup-old-templates.sh; then
        print_info "Old templates cleaned up successfully"
    else
        print_warn "Template cleanup had issues, but build succeeded"
    fi

    print_info "Automated build process completed successfully"
    exit 0
else
    print_error "Template build failed. Old templates were NOT deleted."
    exit 1
fi

