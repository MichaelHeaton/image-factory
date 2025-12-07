# Automation Quick Start

Choose the automation method that works best for your setup:

## 🚀 Option 1: Cron Job (5 minutes)

**Best for**: Quick setup, simple environments

```bash
# 1. Make script executable
chmod +x /path/to/image-factory/scripts/automated-build.sh

# 2. Edit crontab
crontab -e

# 3. Add this line (runs 1st of every month at 2 AM)
0 2 1 * * /path/to/image-factory/scripts/automated-build.sh >> /var/log/image-factory.log 2>&1
```

**Done!** The script will:

- Build new template automatically
- Clean up old templates
- Log everything to `/var/log/image-factory.log`

---

## 🎯 Option 2: GitHub Actions (15 minutes)

**Best for**: Better visibility, manual triggers, notifications

### Setup:

1. **Install self-hosted runner** on a machine with Proxmox access:

   ```bash
   # On your private network machine
   mkdir ~/actions-runner && cd ~/actions-runner
   curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
     https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
   ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN
   ./run.sh
   ```

2. **Add GitHub Secrets** (Settings → Secrets → Actions):

   - `PROXMOX_URL`
   - `PROXMOX_API_TOKEN_ID`
   - `PROXMOX_API_TOKEN_SECRET`
   - `PROXMOX_NODE`
   - `PROXMOX_STORAGE_POOL`
   - `PROXMOX_NETWORK_BRIDGE`

3. **Workflow is ready** at `.github/workflows/build-template.yml`

**Benefits**: Manual triggers, build history, notifications

---

## ⚙️ Option 3: Systemd Timer (10 minutes)

**Best for**: Systemd-based Linux systems, better logging

```bash
# 1. Edit service file with correct paths
sudo nano scripts/image-factory.service
# Update WorkingDirectory and ExecStart paths

# 2. Copy files
sudo cp scripts/image-factory.service /etc/systemd/system/
sudo cp scripts/image-factory.timer /etc/systemd/system/

# 3. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable image-factory.timer
sudo systemctl start image-factory.timer

# 4. Check status
sudo systemctl status image-factory.timer
sudo journalctl -u image-factory.service
```

---

## 🔧 Testing Your Setup

**Test cleanup script** (dry run):

```bash
export PROXMOX_URL="https://proxmox.example.com:8006/api2/json"
export TOKEN_ID="user@pam!token"
export TOKEN_SECRET="your-secret"
export NODE="GPU01"
export TEMPLATE_PATTERN="ubuntu-24.04-hardened-"
export KEEP_COUNT="1"
export DRY_RUN="true"

./scripts/cleanup-old-templates.sh
```

**Test full automation**:

```bash
./scripts/automated-build.sh
```

---

## 📋 What Gets Automated

1. **Monthly Build** (1st of month, 2 AM):

   - Builds new template: `ubuntu-24.04-hardened-YYYYMMDD`
   - Uses VM ID 900
   - Stores on NFS storage pool

2. **Cleanup** (after successful build):
   - Finds all templates matching pattern
   - Keeps newest template(s) (configurable)
   - Deletes older templates
   - Only runs if build succeeded

---

## 🛡️ Safety Features

- ✅ Only deletes templates matching the pattern
- ✅ Keeps newest templates (configurable count)
- ✅ Only deletes after successful build
- ✅ Dry-run mode for testing
- ✅ Confirmation prompts (in interactive mode)

---

## 📚 More Information

See [AUTOMATION.md](./AUTOMATION.md) for detailed documentation.
