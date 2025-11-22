#!/bin/bash
set -euo pipefail

# Initial system setup script for Ubuntu 24.04
# This script runs before security hardening

echo "Starting initial system setup..."

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Upgrade all packages to latest versions
echo "Upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential packages
echo "Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    git \
    vim \
    ufw \
    unattended-upgrades \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    qemu-guest-agent

# Enable and start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Set timezone (default to UTC, can be overridden)
timedatectl set-timezone UTC

# Configure NTP
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# Clean up
apt-get autoremove -y
apt-get autoclean -y

echo "Initial system setup completed successfully."

