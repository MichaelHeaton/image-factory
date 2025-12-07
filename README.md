# Image Factory

A Packer-based image factory for building security-hardened virtual machine templates for Proxmox. This project automates the creation of hardened Ubuntu 24.04 LTS server images that can be used as templates in your Proxmox cluster.

## Overview

This image factory uses HashiCorp Packer to automate the creation of security-hardened VM templates. The build process:

1. Downloads and installs Ubuntu 24.04 LTS Server
2. Applies initial system configuration
3. Implements security hardening best practices
4. Creates a Proxmox template ready for deployment

## Features

- **Proxmox Integration**: Directly builds templates in your Proxmox cluster
- **Security Hardening**: Implements basic security best practices including:
  - SSH key-only authentication (password auth disabled)
  - Disabled root login
  - UFW firewall with secure defaults
  - Automatic security updates
  - Secure kernel parameters
  - Audit logging
  - Password policy enforcement
- **Flexible Configuration**: Supports both configuration files and environment variables
- **Reusable Structure**: Easy to extend with additional OS distributions

## Prerequisites

- **Packer**: Version 1.8.0 or later
  - Download from [packer.io](https://www.packer.io/downloads)
  - Verify installation: `packer version`
- **Proxmox Access**:
  - Access to a Proxmox cluster
  - API token with appropriate permissions (Datacenter.Modify, VM.Allocate, VM.Config.Disk, VM.Config.Network, VM.Config.CDROM, VM.PowerMgmt)
  - Ubuntu 24.04 Server ISO uploaded to Proxmox storage
- **Network Access**: The build machine needs network access to:
  - Proxmox API endpoint
  - Ubuntu package repositories

## Project Structure

```
image-factory/
├── packer/
│   ├── config/
│   │   ├── proxmox.json          # Default Proxmox configuration
│   │   └── proxmox.pkr.hcl       # Shared Proxmox builder config
│   ├── scripts/
│   │   ├── initial-setup.sh      # Initial system setup
│   │   └── security-hardening.sh # Security hardening script
│   ├── ubuntu-24.04/
│   │   ├── ubuntu-24.04.pkr.hcl  # Main Packer configuration
│   │   └── http/
│   │       └── preseed.cfg       # Ubuntu preseed configuration
│   └── env.example               # Environment variables template
├── build.sh                      # Build helper script
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd image-factory
```

### 2. Install Packer

Follow the [official Packer installation guide](https://www.packer.io/docs/install) for your operating system.

### 3. Prepare Proxmox

#### Upload Ubuntu ISO

1. Download Ubuntu 24.04 LTS Server ISO from [ubuntu.com](https://ubuntu.com/download/server)
2. Upload the ISO to your Proxmox storage:
   - Via web UI: Datacenter → Storage → isos → Content → Upload
   - Or via command line: Upload to the `isos` NFS storage pool
3. Note the storage pool name (`isos` for NFS storage) and the ISO path

#### Create API Token

1. In Proxmox web UI, go to Datacenter → Permissions → API Tokens
2. Click "Add" → "API Token"
3. Configure:
   - **Token ID**: e.g., `packer@pam!packer-token`
   - **User**: Select a user (or create one)
   - **Realm**: `pam` (or your authentication realm)
   - **Privilege Separation**: Enable if desired
4. Save the token ID and secret (you'll need both)

### 4. Configure Environment Variables

1. Copy the example environment file:

   ```bash
   cp packer/env.example packer/.env
   ```

2. Edit `packer/.env` with your Proxmox details:

   ```bash
   PROXMOX_URL=https://your-proxmox.example.com:8006/api2/json
   PROXMOX_API_TOKEN_ID=packer@pam!packer-token
   PROXMOX_API_TOKEN_SECRET=your-token-secret-here
   PROXMOX_NODE=pve
   PROXMOX_STORAGE_POOL=vmdks
   PROXMOX_NETWORK_BRIDGE=vmbr0
   ```

   **Note**: The `.env` file is gitignored and will not be committed to version control.

### 5. Update ISO Path (if needed)

Edit `packer/ubuntu-24.04/ubuntu-24.04.pkr.hcl` and update the `iso_file` line if your ISO is stored differently:

```hcl
iso_file = "isos:iso/ubuntu-24.04-server-amd64.iso"
```

The default configuration uses the `isos` NFS storage pool. Adjust the storage pool name and path to match your ISO location if needed.

## Building Images

### Using the Build Script (Recommended)

The build script validates configuration and handles the build process:

```bash
./build.sh
```

The script will:

1. Check for Packer installation
2. Validate environment variables
3. Validate Packer configuration
4. Initialize Packer plugins
5. Build the image

### Using Packer Directly

```bash
cd packer/ubuntu-24.04

# Initialize plugins (first time only)
packer init ubuntu-24.04.pkr.hcl

# Validate configuration
packer validate ubuntu-24.04.pkr.hcl

# Build the image
packer build ubuntu-24.04.pkr.hcl
```

### Build Variables

You can override default VM specifications using environment variables or Packer variables:

```bash
# Using environment variables
export VM_CPU_CORES=4
export VM_MEMORY=4096
export VM_DISK_SIZE=40G
packer build ubuntu-24.04.pkr.hcl

# Or using -var flags
packer build -var 'vm_cpu_cores=4' -var 'vm_memory=4096' ubuntu-24.04.pkr.hcl
```

## Default VM Specifications

- **CPU**: 2 cores
- **RAM**: 2048 MB (2 GB)
- **Disk**: 20 GB
- **Network**: Bridge mode (vmbr0)
- **OS**: Ubuntu 24.04 LTS Server
- **VM ID**: 900 (templates use 900+ range to separate from regular VMs)
- **Template Name**: `ubuntu-24.04-hardened-{YYYYMMDD}` (date suffix added automatically)

### Template Naming and VM IDs

- **VM ID Range**: Templates use VM ID 900+ by default to keep them separate from regular VMs (typically 100-899)
- **Date Suffix**: Template names automatically include a date suffix in YYYYMMDD format (e.g., `ubuntu-24.04-hardened-20251206`)
- **Disk Naming**: Proxmox automatically names disks as `vm-{id}-disk-{num}.raw` (or `base-{id}-disk-{num}.raw` for templates)
  - The disk filename is based on the VM ID, not the VM name (this is a Proxmox limitation)
  - With VM ID 900+, disks will be named like: `vm-900-disk-0.raw` or `base-900-disk-0.raw`
  - The VM ID range (900+) helps identify template disks when viewing storage on the NAS
  - The descriptive VM name with date helps identify templates in the Proxmox UI
- **Disk Organization**: A post-processor script attempts to organize disks into folders named after the VM
  - Due to Proxmox's internal disk management, automatic folder organization has limitations
  - The script provides information about disk locations and recommended folder structure
  - Manual organization may be required for optimal disk organization on NFS storage

## Security Hardening Details

The security hardening script implements the following measures:

### SSH Hardening

- Root login disabled
- Password authentication disabled (key-only)
- Secure cipher and MAC algorithms
- Connection timeout and session limits
- Maximum authentication attempts limited

### Firewall (UFW)

- Default deny incoming traffic
- Allow outgoing traffic
- SSH (port 22) allowed for management

### Automatic Updates

- Automatic security updates enabled
- Unattended upgrades configured
- Automatic cleanup of unused packages

### Kernel Security

- IP forwarding disabled
- Source routing disabled
- ICMP redirects disabled
- SYN flood protection enabled
- IP spoofing protection enabled
- ASLR enabled
- Kernel symbol restrictions

### System Hardening

- Unnecessary packages removed
- Unnecessary services disabled
- Audit logging configured
- Secure file permissions
- Password policy enforcement (14+ character minimum)

### Post-Build Security

**Important**: After deploying a VM from this template:

1. **Change default credentials**: The build uses temporary credentials (`packer`/`packer`)
2. **Add SSH keys**: Configure your SSH public keys for the `packer` user
3. **Review firewall rules**: Adjust UFW rules based on your application needs
4. **Configure monitoring**: Set up your monitoring and logging solutions

## Using the Template

Once the build completes, the template will be available in your Proxmox cluster:

1. In Proxmox web UI, go to your node
2. Click "Create VM"
3. Select "Use existing template"
4. Choose `ubuntu-24.04-hardened`
5. Configure VM settings (CPU, RAM, disk, network)
6. Deploy the VM

### First Boot

On first boot of a VM created from this template:

1. SSH into the VM using the `packer` user (you'll need to add your SSH key first)
2. Change the password: `passwd`
3. Review and adjust firewall rules: `sudo ufw status`
4. Verify security updates: `sudo unattended-upgrades --dry-run`

## Troubleshooting

### Build Fails with "Connection Refused"

- Verify Proxmox URL and port (default: 8006)
- Check firewall rules allowing access to Proxmox API
- Verify API token has correct permissions

### Build Fails with "ISO Not Found"

- Verify ISO is uploaded to Proxmox storage
- Check `iso_file` path in Packer configuration matches your storage
- Verify storage pool name is correct

### SSH Connection Timeout During Build

- Check network connectivity between build machine and Proxmox
- Verify VM network configuration
- Check Proxmox firewall rules
- Increase `ssh_timeout` in Packer configuration if needed

### Template Not Appearing in Proxmox

- Check Proxmox logs: `journalctl -u pveproxy -f`
- Verify build completed successfully (check Packer output)
- Refresh Proxmox web UI
- Check template storage location

## Adding More OS Distributions

To add support for additional operating systems:

1. Create a new directory under `packer/` (e.g., `packer/centos-9/`)
2. Create a Packer configuration file following the Ubuntu example
3. Create OS-specific installation configuration (preseed, kickstart, etc.)
4. Create or adapt provisioning scripts for the new OS
5. Update this README with the new OS information

## Configuration Files

### `packer/config/proxmox.json`

Default Proxmox configuration. This file can be used as a reference but environment variables take precedence.

### `packer/config/proxmox.pkr.hcl`

Shared Proxmox builder configuration with variable definitions and environment variable handling.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Packer Documentation](https://www.packer.io/docs)
- [Proxmox Packer Plugin](https://github.com/hashicorp/packer-plugin-proxmox)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/ubuntu_linux) (for advanced hardening)

## Automation

The Image Factory can be automated to rebuild templates monthly and clean up old versions. See [AUTOMATION.md](./AUTOMATION.md) for detailed setup instructions.

**Quick Start Options:**

1. **Cron Job** (Simplest):

   ```bash
   0 2 1 * * /path/to/image-factory/scripts/automated-build.sh
   ```

2. **GitHub Actions** (Recommended for visibility):

   - Set up self-hosted runner on your private network
   - Configure secrets in GitHub
   - Workflow file: `.github/workflows/build-template.yml`

3. **Jenkins**:

   - Use the provided `Jenkinsfile`
   - Configure credentials in Jenkins

4. **Systemd Timer**:
   ```bash
   sudo cp scripts/image-factory.service /etc/systemd/system/
   sudo cp scripts/image-factory.timer /etc/systemd/system/
   sudo systemctl enable image-factory.timer
   sudo systemctl start image-factory.timer
   ```

The automation will:

- Build a new template with current date (YYYYMMDD format)
- Delete old templates (keeping only the newest by default)
- Only delete old templates if the new build succeeds

## Support

For issues, questions, or contributions, please open an issue on the repository.
