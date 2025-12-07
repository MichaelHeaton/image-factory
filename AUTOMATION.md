# Image Factory Automation Guide

This guide covers options for automating the monthly rebuild of Proxmox templates.

## Architecture Overview

Since Proxmox is on a private network, automation requires one of these approaches:

1. **Self-hosted CI/CD runner** - Run GitHub Actions or GitLab CI runner on your private network
2. **Self-hosted Jenkins** - Run Jenkins on your private network
3. **Cron job** - Simple scheduled task on a machine with network access
4. **VM-based automation** - Run automation inside a VM on your Proxmox cluster

## Option 1: Self-Hosted GitHub Actions Runner (Recommended)

GitHub Actions runners can be installed in several ways:

### Option 1A: Direct Installation on VM/Physical Machine

**Best for**: Simple setup, direct access to network resources

1. **Install GitHub Actions Runner** on a machine with access to your private network:

   ```bash
   # On your private network machine (e.g., a VM or physical server)
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
   ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN
   ./run.sh
   ```

2. **Install Packer** on the same machine:
   ```bash
   # Install Packer (example for Linux)
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

### Option 1B: Docker Container

**Best for**: Easy management, isolation, portability

1. **Use Docker image with runner pre-installed**:

   ```bash
   # Get registration token from GitHub:
   # https://github.com/YOUR_ORG/YOUR_REPO/settings/actions/runners/new

   # Run the setup script
   cd /path/to/image-factory
   GITHUB_REPO="YOUR_ORG/YOUR_REPO" \
   GITHUB_TOKEN="your-registration-token" \
   ./scripts/docker-runner-setup.sh

   # Start the runner
   docker-compose up -d
   ```

2. **Or manually create Docker container**:
   ```bash
   docker run -d \
     --name github-runner \
     --restart unless-stopped \
     -e REPO_URL=https://github.com/YOUR_ORG/YOUR_REPO \
     -e RUNNER_TOKEN=YOUR_TOKEN \
     -e RUNNER_NAME=image-factory-runner \
     --network host \  # Use host network to access private network
     myoung34/github-runner:latest
   ```

**Note**: For Docker, you'll need to either:

- Install Packer inside the container (add to Dockerfile)
- Mount Packer binary from host
- Use a custom Docker image with Packer pre-installed

2. **Configure GitHub Secrets**:

   - Go to repository Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `PROXMOX_URL`: Your Proxmox API URL
     - `PROXMOX_API_TOKEN_ID`: API token ID
     - `PROXMOX_API_TOKEN_SECRET`: API token secret
     - `PROXMOX_NODE`: Node name (e.g., GPU01)
     - `PROXMOX_STORAGE_POOL`: Storage pool (e.g., vmdks)
     - `PROXMOX_NETWORK_BRIDGE`: Network bridge (e.g., vmbr0)

3. **Workflow File**: Already created at `.github/workflows/build-template.yml`

4. **Schedule**: Configured to run on the 1st of every month at 2 AM UTC

### Benefits

- ✅ Integrated with GitHub
- ✅ Easy to trigger manually
- ✅ Good logging and notifications
- ✅ Free for private repos

### Requirements

- Machine/container on private network with internet access (for GitHub communication)
- Packer installed (on VM or in container)
- For Docker: Docker installed, and either Packer in container or mounted from host

---

## Option 2: Self-Hosted Jenkins

### Setup Steps

1. **Install Jenkins** on a machine with access to your private network

2. **Create Pipeline Job**:

   - New Item → Pipeline
   - Copy contents from `Jenkinsfile`
   - Configure credentials in Jenkins:
     - `proxmox-url` (Secret text)
     - `proxmox-token-id` (Secret text)
     - `proxmox-token-secret` (Secret text)

3. **Configure Agent**:

   - Label agent as `proxmox-builder`
   - Ensure Packer is installed on the agent

4. **Schedule**: Configured via cron in Jenkinsfile

### Benefits

- ✅ Full control over infrastructure
- ✅ No external dependencies
- ✅ Rich plugin ecosystem
- ✅ Good for complex workflows

### Requirements

- Jenkins server on private network
- Jenkins agent with Packer installed

---

## Option 3: Simple Cron Job

### Setup Steps

1. **Create cron job** on a machine with network access:

   ```bash
   # Edit crontab
   crontab -e

   # Add this line (runs on 1st of every month at 2 AM)
   0 2 1 * * /path/to/image-factory/scripts/automated-build.sh >> /var/log/image-factory.log 2>&1
   ```

2. **Ensure script is executable**:

   ```bash
   chmod +x /path/to/image-factory/scripts/automated-build.sh
   ```

3. **Configure environment**:
   - Edit `packer/.env` with your Proxmox credentials
   - Optionally set `VM_ID`, `KEEP_COUNT` environment variables

### Benefits

- ✅ Simplest setup
- ✅ No additional infrastructure
- ✅ Works on any Linux machine

### Requirements

- Machine with access to Proxmox API
- Packer installed
- Cron service running

---

## Option 4: VM-Based Automation

Run automation inside a VM on your Proxmox cluster:

1. **Create a small automation VM** (e.g., Ubuntu Server)
2. **Install dependencies**: Packer, Git, curl
3. **Clone repository** or mount as NFS share
4. **Set up cron** or systemd timer
5. **Run automated-build.sh**

### Benefits

- ✅ Fully contained in your infrastructure
- ✅ No external dependencies
- ✅ Easy to manage and update

---

## Template Cleanup Script

The `scripts/cleanup-old-templates.sh` script handles deletion of old templates:

### Usage

```bash
export PROXMOX_URL="https://proxmox.example.com:8006/api2/json"
export TOKEN_ID="user@pam!token"
export TOKEN_SECRET="your-secret"
export NODE="GPU01"
export TEMPLATE_PATTERN="ubuntu-24.04-hardened-"
export KEEP_COUNT="1"  # Keep 1 newest template
export DRY_RUN="false"  # Set to "true" to test without deleting

./scripts/cleanup-old-templates.sh
```

### Safety Features

- Only deletes templates matching the pattern
- Keeps the newest templates (configurable count)
- Dry-run mode for testing
- Confirmation prompt before deletion
- Only runs after successful build (in CI/CD)

---

## Configuration Options

### Environment Variables

| Variable           | Description                        | Default                  |
| ------------------ | ---------------------------------- | ------------------------ |
| `VM_ID`            | VM ID for new template             | `900`                    |
| `TEMPLATE_PATTERN` | Pattern to match templates         | `ubuntu-24.04-hardened-` |
| `KEEP_COUNT`       | Number of newest templates to keep | `1`                      |
| `DRY_RUN`          | Test mode (no deletion)            | `false`                  |

### Customization

**Keep multiple templates** (e.g., keep last 3):

```bash
export KEEP_COUNT="3"
```

**Different template pattern**:

```bash
export TEMPLATE_PATTERN="my-template-"
```

**Test cleanup without deleting**:

```bash
export DRY_RUN="true"
./scripts/cleanup-old-templates.sh
```

---

## Monitoring and Notifications

### GitHub Actions

- Built-in notifications via GitHub
- Email notifications for workflow failures
- Can integrate with Slack/Discord via webhooks

### Jenkins

- Email notifications on failure
- Slack/Discord plugins available
- Build history and logs

### Cron Job

- Add email notification:
  ```bash
  0 2 1 * * /path/to/automated-build.sh 2>&1 | mail -s "Image Factory Build" admin@example.com
  ```

---

## Troubleshooting

### Build Fails

- Check Proxmox API connectivity
- Verify API token permissions
- Check Packer logs
- Ensure storage pool has space

### Cleanup Fails

- Verify API token has delete permissions
- Check template names match pattern
- Review cleanup script logs

### Runner/Agent Issues

- Ensure machine has internet access (for GitHub Actions)
- Verify Packer is installed and in PATH
- Check network connectivity to Proxmox

---

## Security Considerations

1. **API Tokens**: Store securely (GitHub Secrets, Jenkins Credentials, encrypted files)
2. **Network Access**: Limit runner/agent network access to minimum required
3. **Permissions**: Use API tokens with minimum required permissions
4. **Logs**: Be careful not to log sensitive credentials

---

## Recommended Approach

For most use cases, we recommend:

1. **Start with Cron Job** - Simplest, works immediately
2. **Upgrade to GitHub Actions** - If you want better visibility and manual triggers
3. **Use Jenkins** - If you need more complex workflows or integration with other systems

The automation scripts are designed to work with any of these approaches.
