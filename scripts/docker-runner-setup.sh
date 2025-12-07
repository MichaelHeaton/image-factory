#!/bin/bash
# Setup script for running GitHub Actions runner in Docker
# This allows easy management and isolation of the runner

set -euo pipefail

# Configuration
GITHUB_REPO="${GITHUB_REPO:-}"  # e.g., "YOUR_ORG/YOUR_REPO"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Registration token from GitHub
RUNNER_NAME="${RUNNER_NAME:-image-factory-runner}"
DOCKER_NETWORK="${DOCKER_NETWORK:-bridge}"  # Use 'host' to access private network directly

if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Usage: GITHUB_REPO=org/repo GITHUB_TOKEN=token ./docker-runner-setup.sh"
    echo ""
    echo "Get token from: https://github.com/YOUR_ORG/YOUR_REPO/settings/actions/runners/new"
    exit 1
fi

echo "Setting up GitHub Actions runner in Docker..."
echo "Repository: $GITHUB_REPO"
echo "Runner name: $RUNNER_NAME"

# Create docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  github-runner:
    image: myoung34/github-runner:latest
    container_name: ${RUNNER_NAME}
    restart: unless-stopped
    environment:
      - REPO_URL=https://github.com/${GITHUB_REPO}
      - RUNNER_NAME=${RUNNER_NAME}
      - RUNNER_TOKEN=${GITHUB_TOKEN}
      - RUNNER_WORKDIR=/tmp/github-runner
      - RUNNER_ALLOW_RUNASROOT=true
    volumes:
      - runner-data:/tmp/github-runner
      # Mount Packer if installed on host, or install in container
      - /usr/local/bin/packer:/usr/local/bin/packer:ro  # If Packer is on host
    network_mode: ${DOCKER_NETWORK}
    # Use 'host' network mode to access private network resources
    # Or use bridge and configure network access
EOF

echo ""
echo "Created docker-compose.yml"
echo ""
echo "To start the runner:"
echo "  docker-compose up -d"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop:"
echo "  docker-compose down"
echo ""
echo "Note: If using 'host' network mode, the container can access your private network directly."
echo "If using 'bridge' mode, you may need to configure Docker networking."

