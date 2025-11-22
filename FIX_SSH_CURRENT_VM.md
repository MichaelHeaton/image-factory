# Fix SSH on Current VM

## Problem
SSH service fails to start because host keys were deleted during template cleanup.

## Solution (Run via Proxmox Console)

```bash
# 1. Check SSH service status for details
sudo systemctl status ssh.service

# 2. Check journal logs
sudo journalctl -xeu ssh.service | tail -20

# 3. Regenerate SSH host keys (this is the fix)
sudo ssh-keygen -A

# 4. Start SSH service
sudo systemctl start ssh

# 5. Verify SSH is running
sudo systemctl status ssh

# 6. Verify SSH is listening
sudo ss -tlnp | grep :22
```

## Why This Happened
The `clean` role removes SSH host keys to ensure each cloned VM gets unique keys. However, SSH requires at least one host key to start. The keys should be regenerated on first boot, but this didn't happen automatically.

## For Future Builds
We should add a script to regenerate SSH keys on first boot if they don't exist.
