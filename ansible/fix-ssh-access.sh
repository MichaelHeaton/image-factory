#!/bin/bash
# Script to fix SSH access by temporarily re-enabling password auth
# This allows us to add SSH keys, then we can disable password auth again

set -e

echo "=== Fixing SSH Access on Pi5 Nodes ==="
echo ""
echo "This script will:"
echo "1. Temporarily re-enable password authentication"
echo "2. Add SSH keys for packer and michael users"
echo "3. Optionally disable password auth again"
echo ""

cd "$(dirname "$0")"

# Check if SSH key exists
if [ ! -f ~/.ssh/vm-access-key.pub ]; then
    echo "ERROR: SSH key not found at ~/.ssh/vm-access-key.pub"
    exit 1
fi

SSH_KEY=$(cat ~/.ssh/vm-access-key.pub)

# Function to fix SSH on a node
fix_node() {
    local NODE_IP=$1
    local NODE_NAME=$2

    echo ""
    echo "=== Fixing $NODE_NAME ($NODE_IP) ==="

    # Try to connect with password first
    echo "Attempting to connect with password..."
    if sshpass -p 'packer' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 packer@$NODE_IP "echo 'Connected'" 2>/dev/null; then
        echo "✓ Can connect with password"
        USE_PASSWORD=true
    else
        echo "✗ Cannot connect with password - may need console access"
        echo "  You may need to physically access the node or use console"
        return 1
    fi

    if [ "$USE_PASSWORD" = "true" ]; then
        # Temporarily enable password auth
        echo "Temporarily enabling password authentication..."
        sshpass -p 'packer' ssh -o StrictHostKeyChecking=no packer@$NODE_IP "sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart ssh" || true

        # Wait for SSH to restart
        sleep 3

        # Add SSH key to packer user
        echo "Adding SSH key to packer user..."
        sshpass -p 'packer' ssh -o StrictHostKeyChecking=no packer@$NODE_IP "
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            echo '$SSH_KEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        " || echo "Warning: Could not add key to packer user"

        # Add SSH key to michael user
        echo "Adding SSH key to michael user..."
        sshpass -p 'packer' ssh -o StrictHostKeyChecking=no packer@$NODE_IP "sudo -u michael bash -c '
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            echo \"$SSH_KEY\" >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        '" || echo "Warning: Could not add key to michael user"

        # Test SSH key access
        echo "Testing SSH key access..."
        if ssh -i ~/.ssh/vm-access-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 packer@$NODE_IP "echo 'SSH key works!'" 2>/dev/null; then
            echo "✓ SSH key access working!"

            # Ask if we should disable password auth again
            read -p "Disable password authentication again? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Disabling password authentication..."
                ssh -i ~/.ssh/vm-access-key -o StrictHostKeyChecking=no packer@$NODE_IP "sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart ssh"
                echo "✓ Password authentication disabled"
            fi
        else
            echo "✗ SSH key access not working - keeping password auth enabled"
        fi
    fi
}

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: sshpass is not installed"
    echo "Install it with: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# Fix each node
fix_node "172.16.15.13" "adblocker-pi5-01"
fix_node "172.16.15.14" "auth-pi5-01"
fix_node "172.16.15.15" "postgresql-pi5-01"

echo ""
echo "=== Done ==="
echo "You should now be able to SSH using:"
echo "  ssh -i ~/.ssh/vm-access-key packer@172.16.15.13"
echo "  ssh -i ~/.ssh/vm-access-key packer@172.16.15.14"
echo "  ssh -i ~/.ssh/vm-access-key packer@172.16.15.15"

