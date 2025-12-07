#!/bin/bash
# Script to clean up old Proxmox templates, keeping only the newest one
# This script identifies templates by name pattern and deletes older versions

set -euo pipefail

# Configuration
TEMPLATE_PATTERN="${TEMPLATE_PATTERN:-ubuntu-24.04-hardened-}"
KEEP_COUNT="${KEEP_COUNT:-1}"  # Number of newest templates to keep
PROXMOX_URL="${PROXMOX_URL:-}"
TOKEN_ID="${TOKEN_ID:-}"
TOKEN_SECRET="${TOKEN_SECRET:-}"
NODE="${NODE:-GPU01}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required variables
if [ -z "$PROXMOX_URL" ] || [ -z "$TOKEN_ID" ] || [ -z "$TOKEN_SECRET" ]; then
    print_error "Required environment variables not set: PROXMOX_URL, TOKEN_ID, TOKEN_SECRET"
    exit 1
fi

print_info "Template cleanup script"
print_info "Pattern: ${TEMPLATE_PATTERN}*"
print_info "Keep count: ${KEEP_COUNT}"
print_info "Node: ${NODE}"
[ "$DRY_RUN" = "true" ] && print_warn "DRY RUN MODE - No templates will be deleted"

# Get all VMs/templates from the node
print_info "Fetching templates from Proxmox..."
VM_LIST=$(curl -k -s -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
    "${PROXMOX_URL}/nodes/${NODE}/qemu" 2>/dev/null || echo "")

if [ -z "$VM_LIST" ]; then
    print_error "Failed to fetch VM list from Proxmox"
    exit 1
fi

# Extract templates matching the pattern
# Try to use jq if available, otherwise use grep/sed
if command -v jq &> /dev/null; then
    # Use jq for robust JSON parsing
    MATCHING_TEMPLATES=$(echo "$VM_LIST" | jq -r ".data[] | select(.name | startswith(\"${TEMPLATE_PATTERN}\")) | \"\(.vmid):\(.name)\"" | sort -t: -k2 -r)
else
    # Fallback to grep/sed (less robust but works)
    MATCHING_TEMPLATES=$(echo "$VM_LIST" | \
        grep -o "\"vmid\":[0-9]*,\"name\":\"${TEMPLATE_PATTERN}[^\"]*\"" | \
        sed 's/"vmid":\([0-9]*\),"name":"\([^"]*\)"/\1:\2/' | \
        sort -t: -k2 -r)  # Sort by name (date) descending
fi

if [ -z "$MATCHING_TEMPLATES" ]; then
    print_info "No templates found matching pattern: ${TEMPLATE_PATTERN}*"
    exit 0
fi

# Count templates
TEMPLATE_COUNT=$(echo "$MATCHING_TEMPLATES" | wc -l | tr -d ' ')
print_info "Found ${TEMPLATE_COUNT} template(s) matching pattern"

# Display all matching templates
echo ""
print_info "Matching templates:"
echo "$MATCHING_TEMPLATES" | while IFS=: read -r VMID NAME; do
    echo "  VM ID: ${VMID}, Name: ${NAME}"
done

# Calculate how many to delete
TEMPLATES_TO_DELETE=$((TEMPLATE_COUNT - KEEP_COUNT))

if [ $TEMPLATES_TO_DELETE -le 0 ]; then
    print_info "No templates to delete (keeping ${KEEP_COUNT}, found ${TEMPLATE_COUNT})"
    exit 0
fi

print_warn "Will delete ${TEMPLATES_TO_DELETE} old template(s), keeping ${KEEP_COUNT} newest"

# Get templates to delete (skip the first KEEP_COUNT)
TEMPLATES_TO_DELETE_LIST=$(echo "$MATCHING_TEMPLATES" | tail -n +$((KEEP_COUNT + 1)))

echo ""
print_warn "Templates to be deleted:"
echo "$TEMPLATES_TO_DELETE_LIST" | while IFS=: read -r VMID NAME; do
    echo "  VM ID: ${VMID}, Name: ${NAME}"
done

# Delete templates
if [ "$DRY_RUN" = "true" ]; then
    print_info "DRY RUN: Would delete the above templates"
    exit 0
fi

echo ""
read -p "Continue with deletion? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Deletion cancelled"
    exit 0
fi

# Delete each template
DELETED_COUNT=0
FAILED_COUNT=0

echo "$TEMPLATES_TO_DELETE_LIST" | while IFS=: read -r VMID NAME; do
    print_info "Deleting template: ${NAME} (VM ID: ${VMID})..."

    DELETE_RESULT=$(curl -k -s -w "\n%{http_code}" -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
        -X DELETE "${PROXMOX_URL}/nodes/${NODE}/qemu/${VMID}" 2>/dev/null || echo "ERROR:000")

    HTTP_CODE=$(echo "$DELETE_RESULT" | tail -n 1)

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        print_info "Successfully deleted: ${NAME}"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        print_error "Failed to delete: ${NAME} (HTTP ${HTTP_CODE})"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo ""
print_info "Cleanup complete"
print_info "Deleted: ${DELETED_COUNT}, Failed: ${FAILED_COUNT}"

if [ $FAILED_COUNT -gt 0 ]; then
    exit 1
fi

