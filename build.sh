#!/bin/bash
set -euo pipefail

# Build script for Packer Proxmox Image Factory
# This script validates configuration and builds the image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/packer"
UBUNTU_DIR="${PACKER_DIR}/ubuntu-24.04"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Packer is installed
if ! command -v packer &> /dev/null; then
    print_error "Packer is not installed. Please install Packer first."
    print_info "Visit: https://www.packer.io/downloads"
    exit 1
fi

print_info "Packer version: $(packer version)"

# Check if .env file exists
ENV_FILE="${PACKER_DIR}/.env"
if [ ! -f "${ENV_FILE}" ]; then
    print_warn ".env file not found. Creating from example..."
    if [ -f "${PACKER_DIR}/env.example" ]; then
        cp "${PACKER_DIR}/env.example" "${ENV_FILE}"
        print_warn "Please edit ${ENV_FILE} with your Proxmox credentials"
        exit 1
    else
        print_error "env.example file not found. Cannot create .env file."
        exit 1
    fi
fi

# Load environment variables
print_info "Loading environment variables from ${ENV_FILE}..."
set -a
source "${ENV_FILE}"
set +a

# Validate required environment variables
REQUIRED_VARS=(
    "PROXMOX_URL"
    "PROXMOX_API_TOKEN_ID"
    "PROXMOX_API_TOKEN_SECRET"
    "PROXMOX_NODE"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        print_error "  - $var"
    done
    print_info "Please set these in ${ENV_FILE}"
    exit 1
fi

# Validate Packer configuration
print_info "Validating Packer configuration..."
cd "${UBUNTU_DIR}"
if ! packer validate ubuntu-24.04.pkr.hcl; then
    print_error "Packer configuration validation failed"
    exit 1
fi

print_info "Packer configuration is valid"

# Ask for confirmation
print_warn "This will build a new VM template in Proxmox:"
print_info "  Template: ubuntu-24.04-hardened"
print_info "  Node: ${PROXMOX_NODE}"
print_info "  Storage: ${PROXMOX_STORAGE_POOL:-local-lvm}"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Build cancelled"
    exit 0
fi

# Initialize Packer plugins
print_info "Initializing Packer plugins..."
packer init ubuntu-24.04.pkr.hcl

# Build the image
print_info "Starting Packer build..."
if packer build ubuntu-24.04.pkr.hcl; then
    print_info "Build completed successfully!"
    print_info "Template 'ubuntu-24.04-hardened' is now available in Proxmox"
else
    print_error "Build failed!"
    exit 1
fi

