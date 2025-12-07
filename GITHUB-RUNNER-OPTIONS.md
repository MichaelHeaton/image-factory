# GitHub Actions Runner Options

## Quick Answer

**GitHub-hosted runners are VMs** (but won't work for you - they can't access private networks).

**Self-hosted runners can be either:**

- ✅ **Direct installation on a VM/physical machine** (most common)
- ✅ **Docker container** (easier to manage)
- ✅ **Kubernetes pod** (for larger setups)

## Comparison

| Option               | Type                   | Pros                              | Cons                             | Best For              |
| -------------------- | ---------------------- | --------------------------------- | -------------------------------- | --------------------- |
| **Direct Install**   | Process on VM/Physical | Simple, direct network access     | Less portable                    | Single machine setup  |
| **Docker Container** | Container              | Portable, easy updates, isolation | Need to configure network access | Multiple environments |
| **Kubernetes**       | Pod                    | Scalable, orchestrated            | More complex setup               | Large deployments     |

## Recommended: Docker Container

For your use case, **Docker is recommended** because:

1. **Easy management**: Start/stop with `docker-compose`
2. **Isolation**: Runner doesn't affect host system
3. **Portability**: Move between machines easily
4. **Network access**: Use `--network host` to access private network

### Quick Docker Setup

```bash
# 1. Build custom image with Packer (optional, or mount from host)
docker build -f scripts/Dockerfile.runner -t github-runner-packer .

# 2. Run with host network (accesses private network directly)
docker run -d \
  --name github-runner \
  --restart unless-stopped \
  --network host \
  -e REPO_URL=https://github.com/YOUR_ORG/YOUR_REPO \
  -e RUNNER_TOKEN=YOUR_REGISTRATION_TOKEN \
  -e RUNNER_NAME=image-factory-runner \
  github-runner-packer

# 3. Check logs
docker logs -f github-runner
```

### Using docker-compose

```bash
# Use the setup script
GITHUB_REPO="YOUR_ORG/YOUR_REPO" \
GITHUB_TOKEN="your-token" \
./scripts/docker-runner-setup.sh

# Start
docker-compose up -d

# View logs
docker-compose logs -f
```

## Network Configuration

### For Private Network Access

**Option 1: Host Network** (Simplest)

```bash
docker run --network host ...
```

- Container uses host's network directly
- Can access Proxmox API on private network
- No additional configuration needed

**Option 2: Bridge Network** (More isolated)

```bash
# Create custom network
docker network create --driver bridge proxmox-network

# Run container on custom network
docker run --network proxmox-network ...
```

- More isolation
- May need additional routing configuration

## Getting Registration Token

1. Go to: `https://github.com/YOUR_ORG/YOUR_REPO/settings/actions/runners/new`
2. Click "Generate new token"
3. Copy the token (expires in 1 hour)
4. Use it when configuring the runner

## Verification

After setup, verify the runner appears in GitHub:

- Go to: `https://github.com/YOUR_ORG/YOUR_REPO/settings/actions/runners`
- You should see your runner listed as "Idle" or "Online"

## Troubleshooting

**Runner not connecting:**

- Check internet connectivity from container/host
- Verify registration token is valid (expires in 1 hour)
- Check firewall rules

**Can't access Proxmox:**

- If using Docker: Try `--network host`
- Verify Proxmox API is accessible from runner location
- Check API token permissions

**Packer not found:**

- Install Packer in container (use Dockerfile.runner)
- Or mount Packer binary from host: `-v /usr/local/bin/packer:/usr/local/bin/packer:ro`
