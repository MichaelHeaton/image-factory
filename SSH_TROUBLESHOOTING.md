# SSH Troubleshooting Guide

## Issue: Connection Refused After Cloning

### Root Causes:
1. **SSH service not enabled on boot** - Fixed in base role
2. **Password authentication disabled** - Security hardening requires SSH keys
3. **UFW firewall blocking** - Should allow SSH, but needs verification

### Quick Fixes for Current VM:

1. **Check SSH service status:**
   ```bash
   # Via Proxmox console
   sudo systemctl status ssh
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

2. **Check UFW firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 22/tcp
   sudo ufw reload
   ```

3. **Verify SSH is listening:**
   ```bash
   sudo ss -tlnp | grep :22
   ```

### Authentication Methods:

**Password authentication is DISABLED** (security hardening):
- ❌ `ssh packer@172.16.15.125` (password) - Won't work
- ✅ `ssh -i ~/.ssh/vm-access-key michael@172.16.15.125` (key) - Should work

### For Future Builds:

The following fixes have been applied:
- ✅ SSH service enabled in base role
- ✅ SSH service name corrected (`ssh` not `sshd`)
- ✅ SSH port verification added
- ✅ UFW SSH rule verification added

### Testing SSH Connection:

```bash
# Test with SSH key
ssh -i ~/.ssh/vm-access-key michael@172.16.15.125

# Or add to SSH config
cat >> ~/.ssh/config << 'CONFIG'
Host vm-*
    User michael
    IdentityFile ~/.ssh/vm-access-key
    StrictHostKeyChecking no
CONFIG

# Then connect
ssh vm-172.16.15.125
```
