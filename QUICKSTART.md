# Quick Start Guide

## Prerequisites Checklist

- [ ] Packer installed (`packer version`)
- [ ] Ubuntu 24.04 Server ISO uploaded to Proxmox
- [ ] Proxmox API token created
- [ ] Environment variables configured

## Setup (One-Time)

```bash
# 1. Copy environment template
cp packer/env.example packer/.env

# 2. Edit with your Proxmox details
nano packer/.env
```

Required variables in `packer/.env`:
- `PROXMOX_URL`
- `PROXMOX_API_TOKEN_ID`
- `PROXMOX_API_TOKEN_SECRET`
- `PROXMOX_NODE`

## Build Image

```bash
# Using the build script (recommended)
./build.sh

# Or using Packer directly
cd packer/ubuntu-24.04
packer init ubuntu-24.04.pkr.hcl
packer build ubuntu-24.04.pkr.hcl
```

## After Build

1. Template `ubuntu-24.04-hardened` will be available in Proxmox
2. Deploy VMs from the template
3. **Important**: Change default credentials and add SSH keys on first boot

## Troubleshooting

- **Connection refused**: Check Proxmox URL and firewall
- **ISO not found**: Verify ISO path in `ubuntu-24.04.pkr.hcl`
- **SSH timeout**: Check network and increase timeout in config

See [README.md](README.md) for detailed documentation.

