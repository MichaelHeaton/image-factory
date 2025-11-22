#!/bin/bash
set -euo pipefail

# Test script for Proxmox connection and configuration
# This script validates that the Proxmox API is accessible and credentials work

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/packer"
ENV_FILE="${PACKER_DIR}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Check if .env file exists
if [ ! -f "${ENV_FILE}" ]; then
    print_error ".env file not found at ${ENV_FILE}"
    print_info "Please copy packer/env.example to packer/.env and fill in your credentials"
    exit 1
fi

print_info "Loading environment variables from ${ENV_FILE}..."
set -a
source "${ENV_FILE}"
set +a

# Check required variables
REQUIRED_VARS=(
    "PROXMOX_URL"
    "PROXMOX_API_TOKEN_ID"
    "PROXMOX_API_TOKEN_SECRET"
    "PROXMOX_NODE"
)

print_test "Checking required environment variables..."
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
        print_error "  Missing: $var"
    else
        # Mask sensitive values
        if [[ "$var" == *"SECRET"* ]] || [[ "$var" == *"TOKEN"* ]]; then
            print_info "  Found: $var (hidden)"
        else
            print_info "  Found: $var=${!var}"
        fi
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_error "Missing required environment variables"
    exit 1
fi

print_info "All required variables are set"

# Extract username and token from token ID
# Format: user@realm!token-name
# Note: Some Proxmox setups might use different formats, so we'll be flexible
if [[ "$PROXMOX_API_TOKEN_ID" =~ ^([^@!]+)@([^!]+)!(.+)$ ]]; then
    PROXMOX_USER="${BASH_REMATCH[1]}"
    PROXMOX_REALM="${BASH_REMATCH[2]}"
    PROXMOX_TOKEN_NAME="${BASH_REMATCH[3]}"
    print_info "Token parsed: User=${PROXMOX_USER}, Realm=${PROXMOX_REALM}, Token=${PROXMOX_TOKEN_NAME}"
elif [[ "$PROXMOX_API_TOKEN_ID" =~ @ ]] && [[ ! "$PROXMOX_API_TOKEN_ID" =~ ! ]]; then
    # Has @ but missing ! - need token name
    print_error "Token ID is missing the token name part."
    print_error "Current format: ${PROXMOX_API_TOKEN_ID}"
    print_error "Required format: user@realm!token-name"
    print_info ""
    print_info "In Proxmox UI, when you create an API token, the full token ID includes:"
    print_info "  - User: e.g., 'terraform'"
    print_info "  - Realm: e.g., 'pam'"
    print_info "  - Token Name: the name you gave the token (e.g., 'packer-token')"
    print_info ""
    print_info "The full token ID should look like: terraform@pam!packer-token"
    print_info ""
    print_info "Please check your Proxmox UI:"
    print_info "  Datacenter → Permissions → API Tokens"
    print_info "  Find your token and copy the full Token ID (including the !token-name part)"
    exit 1
else
    print_error "Invalid PROXMOX_API_TOKEN_ID format."
    print_error "Received: ${PROXMOX_API_TOKEN_ID}"
    print_error "Expected format: user@realm!token-name"
    print_info "Example: root@pam!packer-token"
    exit 1
fi

# Test 1: Check if curl is available
print_test "Test 1: Checking for curl..."
if ! command -v curl &> /dev/null; then
    print_error "curl is not installed. Please install curl to test the connection."
    exit 1
fi
print_info "curl is available"

# Test 2: Test Proxmox API connectivity
print_test "Test 2: Testing Proxmox API connectivity..."
PROXMOX_BASE_URL="${PROXMOX_URL%/api2/json}"

# Test basic connectivity (without auth, using -k for self-signed certs)
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 10 "${PROXMOX_BASE_URL}/api2/json/version" 2>&1 || echo "000")

if [[ "$HTTP_CODE" =~ ^[0-9]+$ ]] && [[ "$HTTP_CODE" -ge 200 ]] && [[ "$HTTP_CODE" -lt 500 ]]; then
    print_info "Proxmox API is reachable (HTTP ${HTTP_CODE})"
elif [ "$HTTP_CODE" = "000" ]; then
    print_error "Cannot reach Proxmox API at ${PROXMOX_BASE_URL}"
    print_info "Possible issues:"
    print_info "  - Network connectivity problem"
    print_info "  - Firewall blocking port 8006"
    print_info "  - Incorrect URL"
    print_info "  - Server is down"
    exit 1
else
    print_warn "Proxmox API returned HTTP ${HTTP_CODE} (may still be accessible)"
fi

# Test 3: Test authentication
print_test "Test 3: Testing Proxmox API authentication..."
AUTH_HEADER="PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}"
print_info "Using token ID: ${PROXMOX_API_TOKEN_ID}"

# Try API token authentication
AUTH_RESPONSE=$(curl -k -s -w "\n%{http_code}" \
    -H "Authorization: ${AUTH_HEADER}" \
    "${PROXMOX_BASE_URL}/api2/json/version" 2>&1)

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AUTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    print_info "Authentication successful!"
    if command -v jq &> /dev/null; then
        VERSION=$(echo "$RESPONSE_BODY" | jq -r '.data.version // "unknown"')
        RELEASE=$(echo "$RESPONSE_BODY" | jq -r '.data.release // "unknown"')
        print_info "Proxmox version: ${VERSION} (${RELEASE})"
    else
        print_info "Proxmox API responded successfully"
        print_warn "Install 'jq' for better output formatting: brew install jq"
    fi
else
    print_error "Authentication failed (HTTP ${HTTP_CODE})"
    if [ -n "$RESPONSE_BODY" ]; then
        print_error "Response: ${RESPONSE_BODY}"
    fi
    print_info ""
    print_info "Troubleshooting steps:"
    print_info "  1. Verify PROXMOX_API_TOKEN_ID format: user@realm!token-name"
    print_info "     Current format looks correct: ${PROXMOX_USER}@${PROXMOX_REALM}!${PROXMOX_TOKEN_NAME}"
    print_info "  2. Verify PROXMOX_API_TOKEN_SECRET matches the token in Proxmox"
    print_info "  3. Check token hasn't expired in Proxmox UI"
    print_info "  4. Verify token has required permissions:"
    print_info "     - Datacenter.Modify"
    print_info "     - VM.Allocate"
    print_info "     - VM.Config.Disk"
    print_info "     - VM.Config.Network"
    print_info "     - VM.Config.CDROM"
    print_info "     - VM.PowerMgmt"
    print_info ""
    print_info "You can test the token manually with:"
    print_info "  curl -k -H \"Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=<secret>\" \\"
    print_info "    ${PROXMOX_BASE_URL}/api2/json/version"
    exit 1
fi

# Test 4: Test node access
print_test "Test 4: Testing access to node: ${PROXMOX_NODE}..."
NODE_RESPONSE=$(curl -k -s -w "\n%{http_code}" \
    -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}" \
    "${PROXMOX_BASE_URL}/api2/json/nodes/${PROXMOX_NODE}/status" 2>&1)

NODE_HTTP_CODE=$(echo "$NODE_RESPONSE" | tail -n1)
NODE_BODY=$(echo "$NODE_RESPONSE" | sed '$d')

if [ "$NODE_HTTP_CODE" = "200" ]; then
    print_info "Node '${PROXMOX_NODE}' is accessible"
    if command -v jq &> /dev/null; then
        NODE_STATUS=$(echo "$NODE_BODY" | jq -r '.data.status // "unknown"')
        NODE_UPTIME=$(echo "$NODE_BODY" | jq -r '.data.uptime // "unknown"')
        print_info "  Status: ${NODE_STATUS}"
        print_info "  Uptime: ${NODE_UPTIME} seconds"
    fi
else
    print_error "Cannot access node '${PROXMOX_NODE}' (HTTP ${NODE_HTTP_CODE})"
    print_error "Response: ${NODE_BODY}"
    print_info "Please check:"
    print_info "  1. Node name is correct (check Proxmox web UI)"
    print_info "  2. Token has permissions to access this node"
    exit 1
fi

# Test 5: Test storage pool access
if [ -n "${PROXMOX_STORAGE_POOL:-}" ]; then
    print_test "Test 5: Testing access to storage pool: ${PROXMOX_STORAGE_POOL}..."
    STORAGE_RESPONSE=$(curl -k -s -w "\n%{http_code}" \
        -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}" \
        "${PROXMOX_BASE_URL}/api2/json/nodes/${PROXMOX_NODE}/storage/${PROXMOX_STORAGE_POOL}/status" 2>&1)

    STORAGE_HTTP_CODE=$(echo "$STORAGE_RESPONSE" | tail -n1)
    STORAGE_BODY=$(echo "$STORAGE_RESPONSE" | sed '$d')

    if [ "$STORAGE_HTTP_CODE" = "200" ]; then
        print_info "Storage pool '${PROXMOX_STORAGE_POOL}' is accessible"
        if command -v jq &> /dev/null; then
            STORAGE_TOTAL=$(echo "$STORAGE_BODY" | jq -r '.data.total // 0')
            STORAGE_USED=$(echo "$STORAGE_BODY" | jq -r '.data.used // 0')
            STORAGE_AVAIL=$(echo "$STORAGE_BODY" | jq -r '.data.avail // 0')
            if [ "$STORAGE_TOTAL" != "0" ]; then
                STORAGE_PCT=$((STORAGE_USED * 100 / STORAGE_TOTAL))
                print_info "  Total: $(numfmt --to=iec-i --suffix=B ${STORAGE_TOTAL} 2>/dev/null || echo "${STORAGE_TOTAL} bytes")"
                print_info "  Used: $(numfmt --to=iec-i --suffix=B ${STORAGE_USED} 2>/dev/null || echo "${STORAGE_USED} bytes") (${STORAGE_PCT}%)"
                print_info "  Available: $(numfmt --to=iec-i --suffix=B ${STORAGE_AVAIL} 2>/dev/null || echo "${STORAGE_AVAIL} bytes")"
            fi
        fi
    else
        print_warn "Cannot access storage pool '${PROXMOX_STORAGE_POOL}' (HTTP ${STORAGE_HTTP_CODE})"
        print_warn "This may be normal if the storage pool name is incorrect or not accessible"
    fi
fi

# Test 6: Validate Packer configuration
print_test "Test 6: Validating Packer configuration..."
if ! command -v packer &> /dev/null; then
    print_warn "Packer is not installed. Skipping Packer validation."
    print_info "Install Packer: https://www.packer.io/downloads"
else
    cd "${SCRIPT_DIR}/packer/ubuntu-24.04"
    if packer validate ubuntu-24.04.pkr.hcl > /dev/null 2>&1; then
        print_info "Packer configuration is valid"
    else
        print_warn "Packer configuration validation had issues"
        print_info "Running packer validate for details..."
        packer validate ubuntu-24.04.pkr.hcl || true
    fi
fi

# Summary
echo ""
print_info "=========================================="
print_info "All tests completed successfully!"
print_info "=========================================="
print_info "Your Proxmox configuration is ready to use."
print_info ""
print_info "Next steps:"
print_info "  1. Ensure Ubuntu 24.04 ISO is uploaded to Proxmox"
print_info "  2. Run: ./build.sh"
print_info ""

