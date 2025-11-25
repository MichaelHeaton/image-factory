#!/bin/bash
# Script to troubleshoot and fix NVME detection on Raspberry Pi 5

set -e

echo "=== NVME Detection Troubleshooting ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "Step 1: Loading NVME kernel modules..."
modprobe nvme 2>/dev/null || echo "  Warning: Could not load nvme module"
modprobe nvme_core 2>/dev/null || echo "  Warning: Could not load nvme_core module"

echo ""
echo "Step 2: Checking loaded modules..."
lsmod | grep nvme || echo "  No NVME modules loaded"

echo ""
echo "Step 3: Forcing PCIe bus rescan..."
echo 1 > /sys/bus/pci/rescan
sleep 3

echo ""
echo "Step 4: Checking for NVME devices..."
if ls /dev/nvme* 1> /dev/null 2>&1; then
    echo "  ✓ NVME devices found!"
    ls -la /dev/nvme*
    lsblk | grep nvme
else
    echo "  ✗ No NVME devices found"
fi

echo ""
echo "Step 5: Checking PCIe link status..."
dmesg | grep "1000110000.pcie" | grep -E "(link up|link down)" | tail -1

echo ""
echo "Step 6: Checking for PCIe devices..."
lspci -nn | grep -i nvme || echo "  No NVME controllers in PCIe"

echo ""
echo "Step 7: Checking PCIe bus 1..."
lspci -b 1 2>/dev/null || echo "  Bus 1 not accessible or empty"

echo ""
echo "=== Summary ==="
if ls /dev/nvme* 1> /dev/null 2>&1; then
    echo "✓ NVME is detected and working!"
    echo ""
    echo "Next steps:"
    echo "  1. Partition the drive: sudo parted /dev/nvme0n1 --script mklabel gpt"
    echo "  2. Create partition: sudo parted /dev/nvme0n1 --script mkpart primary ext4 0% 100%"
    echo "  3. Format: sudo mkfs.ext4 /dev/nvme0n1p1"
else
    echo "✗ NVME is NOT detected"
    echo ""
    echo "The PCIe link is down, which means:"
    echo "  1. M.2 HAT may not be properly connected to GPIO pins"
    echo "  2. NVME drive may not be inserted correctly"
    echo "  3. Hardware compatibility issue"
    echo ""
    echo "Physical checks needed:"
    echo "  - Power off the Pi"
    echo "  - Reseat M.2 HAT on GPIO pins (ensure all pins make contact)"
    echo "  - Reseat NVME drive in M.2 slot (should click into place)"
    echo "  - Verify USB-C power is 27W+ (5.4A @ 5V)"
    echo "  - Power on and check again"
fi

