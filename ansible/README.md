# Ansible Hardening Playbook

This directory contains Ansible playbooks and roles for hardening Linux systems, including both Proxmox VMs and Raspberry Pi nodes.

## Overview

The `linux-playbook.yml` playbook applies security hardening to Linux systems by running the following roles:

- **base**: System updates, essential packages, timezone configuration
- **users**: User management and SSH key setup
- **security**: Comprehensive security hardening (SSH, firewall, kernel, audit, etc.)
- **storage**: Storage configuration and log rotation
- **clean**: Cleanup tasks (typically used for image building)

## Prerequisites

1. **Ansible**: Version 2.9 or later

   ```bash
   # macOS
   brew install ansible

   # Linux
   sudo apt install ansible  # Debian/Ubuntu
   sudo yum install ansible   # RHEL/CentOS
   ```

2. **Ansible Collections**: Install required collections

   ```bash
   ansible-galaxy collection install -r linux-requirements.yml
   ```

3. **SSH Access**: Ensure you can SSH to target hosts with the configured credentials

## Inventory Files

### Raspberry Pi 5 Nodes

The `inventory/pi5.yml` file contains configuration for Raspberry Pi 5 nodes:

- **adblocker-pi5-01**: 172.16.15.13
- **auth-pi5-01**: 172.16.15.14
- **postgresql-pi5-01**: 172.16.15.15

All nodes use:

- Username: `packer`
- Python interpreter: `/usr/bin/python3`
- Hostnames are automatically configured during playbook execution

**Password Configuration**: Passwords are stored in a separate vault file (`inventory/pi5-vault.yml`) that is gitignored. To set up:

```bash
# Copy the example vault file
cp ansible/inventory/pi5-vault.yml.example ansible/inventory/pi5-vault.yml

# Edit the vault file with your actual passwords
nano ansible/inventory/pi5-vault.yml
```

## Running the Playbook

### Against Raspberry Pi 5 Nodes

**First-time setup**:

```bash
cd ansible

# Copy and configure the password vault file
cp inventory/pi5-vault.yml.example inventory/pi5-vault.yml
# Edit inventory/pi5-vault.yml with your actual passwords

# Install required collections (first time only)
ansible-galaxy collection install -r linux-requirements.yml
```

**Running the playbook**:

```bash
# Run against all Pi5 nodes (merges vault file for passwords)
ansible-playbook -i inventory/pi5.yml -i inventory/pi5-vault.yml linux-playbook.yml

# Run against a specific node
ansible-playbook -i inventory/pi5.yml -i inventory/pi5-vault.yml linux-playbook.yml --limit adblocker-pi5-01

# Run with verbose output
ansible-playbook -i inventory/pi5.yml -i inventory/pi5-vault.yml linux-playbook.yml -v

# Run with extra verbosity (debug mode)
ansible-playbook -i inventory/pi5.yml -i inventory/pi5-vault.yml linux-playbook.yml -vvv
```

**Note**: The playbook will automatically:

- Set the correct hostname for each node based on the `target_hostname` variable
- Configure static IP addresses using netplan (when `static_ip` variable is defined in inventory)

### Against Custom Inventory

You can create your own inventory file or use inline inventory:

```bash
# Using inline inventory
ansible-playbook -i "172.16.15.13," linux-playbook.yml \
  -e "ansible_user=packer" \
  -e "ansible_password=packer" \
  -e "is_raspberry_pi=true"

# Using a custom inventory file
ansible-playbook -i my-inventory.yml linux-playbook.yml
```

## What Gets Hardened

### Base Role

- System package updates
- Essential packages installation
- **Hostname configuration**: Automatically sets hostname based on `target_hostname` variable
- **Static IP configuration**: Automatically configures static IP addresses using netplan (when `static_ip` variable is defined)
- Timezone configuration (UTC)
- SSH service configuration
- **Note**: qemu-guest-agent is automatically skipped for Raspberry Pi nodes

### Users Role

- Creates `michael` user with sudo access
- Configures passwordless sudo
- Sets up SSH keys (if `~/.ssh/vm-access-key.pub` exists)

### Security Role

- SSH hardening (key-only auth, secure ciphers, etc.)
- UFW firewall configuration
- Automatic security updates
- Kernel security parameters
- Audit logging
- Password policy
- File permissions
- Fail2ban
- AppArmor
- GRUB security
- Network hardening
- MOTD/banner
- Filesystem security

### Storage Role

- Creates `/data` directory
- Configures log rotation
- Limits systemd journal size

### Clean Role

- Cleans audit logs
- Removes temporary files
- Cleans SSH host keys (for image building)
- Cleans machine-id (for image building)

## Raspberry Pi Specific Notes

The playbook automatically detects Raspberry Pi nodes using the `is_raspberry_pi` variable set in the inventory. When this variable is `true`:

- **qemu-guest-agent** is not installed (VM-specific package)
- All other hardening steps apply normally

## Verifying Hardening

After running the playbook, verify the hardening:

```bash
# Check SSH configuration
ssh -v packer@<pi-ip>

# Check firewall status
ansible pi5 -i inventory/pi5.yml -m shell -a "sudo ufw status" -e "ansible_become=yes"

# Check automatic updates
ansible pi5 -i inventory/pi5.yml -m shell -a "sudo unattended-upgrades --dry-run" -e "ansible_become=yes"

# Check audit logging
ansible pi5 -i inventory/pi5.yml -m shell -a "sudo systemctl status auditd" -e "ansible_become=yes"
```

## Troubleshooting

### Connection Issues

If you get connection errors:

```bash
# Test connectivity
ansible pi5 -i inventory/pi5.yml -m ping

# Test with verbose output
ansible pi5 -i inventory/pi5.yml -m ping -vvv
```

### Permission Issues

If you get permission errors:

```bash
# Ensure the user has sudo access
ansible pi5 -i inventory/pi5.yml -m shell -a "sudo whoami" -e "ansible_become=yes"
```

### Python Interpreter Issues

If you get Python errors:

```bash
# Check Python version on target
ansible pi5 -i inventory/pi5.yml -m shell -a "python3 --version"

# Override Python interpreter if needed
ansible-playbook -i inventory/pi5.yml linux-playbook.yml \
  -e "ansible_python_interpreter=/usr/bin/python3"
```

## Security Notes

⚠️ **Important**:

1. **Password Vault**: Passwords are stored in `inventory/pi5-vault.yml` which is gitignored. Never commit this file to version control.

2. **After initial setup**:
   - **Change the default password** on all nodes
   - **Set up SSH key authentication** and disable password auth
   - Consider using **Ansible Vault** for additional encryption:

```bash
# Encrypt vault file with Ansible Vault (optional, additional security)
ansible-vault encrypt inventory/pi5-vault.yml

# Run playbook with encrypted vault
ansible-playbook -i inventory/pi5.yml -i inventory/pi5-vault.yml linux-playbook.yml --ask-vault-pass
```

3. **Alternative**: Use SSH keys instead of passwords by setting up key-based authentication first, then you can remove the password vault file entirely.

## Customization

### Skipping Roles

You can skip specific roles if needed:

```bash
# Skip the clean role (useful for live systems)
ansible-playbook -i inventory/pi5.yml linux-playbook.yml --skip-tags clean
```

### Running Specific Roles

You can run only specific roles:

```bash
# Only run security hardening
ansible-playbook -i inventory/pi5.yml linux-playbook.yml --tags security
```

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
