# Ansible Inventory Files

This directory contains inventory files for different target systems.

## Raspberry Pi 5 Nodes

### Files

- **`pi5.yml`**: Main inventory file with host definitions (safe to commit)
- **`pi5-vault.yml.example`**: Example password vault file (safe to commit)
- **`pi5-vault.yml`**: Password vault file (gitignored, do NOT commit)

### Setup

1. Copy the example vault file:

   ```bash
   cp pi5-vault.yml.example pi5-vault.yml
   ```

2. Edit `pi5-vault.yml` with your actual passwords:

   ```bash
   nano pi5-vault.yml
   ```

3. Run the playbook with both inventory files:
   ```bash
   ansible-playbook -i pi5.yml -i pi5-vault.yml ../linux-playbook.yml
   ```

### Hostnames

The inventory automatically configures hostnames:

- `172.16.15.13` → `swarm-pi5-01`
- `172.16.15.14` → `swarm-pi5-02`
- `172.16.15.15` → `swarm-pi5-03`
- `172.16.15.16` → `swarm-pi5-04`

Hostnames are set automatically during playbook execution.

### Static IP Configuration

The inventory includes static IP configuration for each node:

- **swarm-pi5-01**: `172.16.15.13/24` (Storage: `172.16.30.13/24`)
- **swarm-pi5-02**: `172.16.15.14/24` (Storage: `172.16.30.14/24`)
- **swarm-pi5-03**: `172.16.15.15/24` (Storage: `172.16.30.15/24`)
- **swarm-pi5-04**: `172.16.15.16/24` (Storage: `172.16.30.16/24`)

Network settings (configured in group vars):

- **Gateway**: `172.16.15.1` (UniFi Controller)
- **DNS Servers**: `172.16.15.1` (UniFi), `1.1.1.1` (Cloudflare fallback)
- **Network Interface**: Automatically detected (typically `eth0`)

Static IP addresses are configured automatically during playbook execution using netplan.

### Security

⚠️ **Never commit `pi5-vault.yml` to version control!**

The file is gitignored, but always verify before committing:

```bash
git status
git check-ignore pi5-vault.yml  # Should show the file is ignored
```
