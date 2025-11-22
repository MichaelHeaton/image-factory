#!/bin/bash
set -euo pipefail

# Security hardening script for Ubuntu 24.04
# Implements basic security best practices

echo "Starting security hardening..."

# ============================================================================
# SSH Hardening
# ============================================================================
echo "Hardening SSH configuration..."

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH security settings
cat >> /etc/ssh/sshd_config << 'EOF'

# Security hardening settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
Compression no
Protocol 2

# Cipher and MAC algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com
EOF

# Restart SSH service
systemctl restart sshd

# ============================================================================
# Firewall Configuration (UFW)
# ============================================================================
echo "Configuring firewall..."

# Reset UFW to defaults
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (required for management)
ufw allow 22/tcp comment 'SSH'

# Enable UFW
ufw --force enable

# ============================================================================
# Automatic Security Updates
# ============================================================================
echo "Configuring automatic security updates..."

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# ============================================================================
# Kernel Security Parameters
# ============================================================================
echo "Configuring kernel security parameters..."

# Backup sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup

# Add security-focused kernel parameters
cat >> /etc/sysctl.conf << 'EOF'

# Security hardening kernel parameters
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bad ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 if not needed (commented out by default)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Restrict core dumps
fs.suid_dumpable = 0
kernel.core_uses_pid = 1

# Hide kernel symbols
kernel.kptr_restrict = 2

# Restrict access to kernel logs
kernel.dmesg_restrict = 1

# Enable ASLR
kernel.randomize_va_space = 2
EOF

# Apply sysctl settings
sysctl -p

# ============================================================================
# Remove Unnecessary Packages
# ============================================================================
echo "Removing unnecessary packages..."

# Remove packages that are typically not needed on servers
apt-get remove -y --purge \
    snapd \
    ubuntu-advantage-tools \
    popularity-contest \
    || true

# Clean up
apt-get autoremove -y
apt-get autoclean -y

# ============================================================================
# Disable Unnecessary Services
# ============================================================================
echo "Disabling unnecessary services..."

# Disable services that are not typically needed
systemctl disable bluetooth 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true

# ============================================================================
# Audit Logging
# ============================================================================
echo "Configuring audit logging..."

# Install auditd if not present
apt-get install -y auditd audispd-plugins || true

# Configure auditd
cat > /etc/audit/rules.d/99-hardening.rules << 'EOF'
# Remove all existing rules
-D

# Buffer size
-b 8192

# Failure mode
-f 1

# Make the configuration immutable
-e 2
EOF

# Enable and start auditd
systemctl enable auditd
systemctl start auditd || true

# ============================================================================
# File Permissions
# ============================================================================
echo "Setting secure file permissions..."

# Secure important files
chmod 644 /etc/passwd
chmod 600 /etc/shadow
chmod 644 /etc/group
chmod 600 /etc/gshadow

# Secure log files
find /var/log -type f -exec chmod 640 {} \;
find /var/log -type d -exec chmod 750 {} \;

# ============================================================================
# Password Policy
# ============================================================================
echo "Configuring password policy..."

# Install libpam-pwquality if not present
apt-get install -y libpam-pwquality || true

# Configure password quality
cat > /etc/security/pwquality.conf << 'EOF'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

# Configure PAM password policy
if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
    sed -i 's/pam_unix.so/pam_unix.so minlen=14 remember=5/' /etc/pam.d/common-password
fi

# ============================================================================
# Final Cleanup
# ============================================================================
echo "Performing final cleanup..."

# Clear bash history
history -c
history -w

# Clear logs (optional - commented out to preserve build logs)
# find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

# Update package database
apt-get update -y

echo "Security hardening completed successfully."
echo "System is now hardened with basic security best practices."

