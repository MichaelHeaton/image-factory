# SSH Key Configuration Fix

## Problem

The image factory only looked for `~/.ssh/vm-access-key.pub` and would disable password authentication even if no SSH keys were found, locking users out of newly created VMs.

## Solution

### Changes Made

1. **Updated `ansible/roles/users/tasks/main.yml`**:

   - Now checks for multiple common SSH key files:
     - `vm-access-key.pub` (original)
     - `id_ed25519.pub` (common Ed25519 key)
     - `id_rsa.pub` (common RSA key)
   - Adds ALL found SSH keys to both `packer` and `michael` users
   - Shows a warning if no keys are found (but doesn't fail)

2. **Updated `ansible/roles/security/tasks/ssh/main.yml`**:
   - Keeps password authentication ENABLED if no SSH keys are found
   - Shows clear warnings when password auth is enabled
   - Only disables password auth when SSH keys are present

### Result

- ✅ **Future builds**: SSH keys from `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub` will be automatically included
- ✅ **No keys found**: Password auth stays enabled (with warning) so you can still access the VM
- ✅ **Security**: Password auth is automatically disabled when SSH keys are present

## Testing

After rebuilding an image:

1. Check that SSH keys were added:

   ```bash
   ssh packer@<vm-ip>  # Should work without password
   ```

2. Verify password auth is disabled:
   ```bash
   # This should fail
   ssh -o PreferredAuthentications=password packer@<vm-ip>
   ```

## For Current VM

The current Plex VM (102) was built before this fix. To fix it:

1. Enable password auth temporarily (via Proxmox console)
2. Run the Plex Ansible playbook which will add SSH keys
3. Playbook will disable password auth automatically

See `../plex/docs/QUICK-START.md` for instructions.
